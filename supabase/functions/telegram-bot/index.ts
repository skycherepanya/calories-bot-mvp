import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai@0.1.1";
import ExifReader from "npm:exifreader@4.23.1";

const TELEGRAM_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const ALLOWED_USER_ID = parseInt(Deno.env.get('ALLOWED_USER_ID') || '0');
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!);

const MAIN_KEYBOARD = {
  keyboard: [
    [{ text: "📊 Статистика" }, { text: "⚖️ Записати вагу" }],
    [{ text: "📅 Запис за вчора" }]
  ],
  resize_keyboard: true,
  is_persistent: true
};

const SYSTEM_PROMPT = `
You are an expert clinical nutritionist AI. Analyze the image OR text description of food.

CRITICAL ACCURACY RULES:
1. Scale & Depth: Do not assume standard massive restaurant portions. Analyze the plate size and estimate realistic, moderate weights (e.g., standard side of rice is usually 100-150g).
2. Cooked vs Raw: For rice, pasta, buckwheat, and oats, ALWAYS calculate macros based on COOKED weight, not dry weight.
3. Realistic Macros: Do not overinflate carbohydrates or fats. A standard small piece of meat is 80-100g.
4. Deficit Buffer: Calculate the exact Kcal, then MULTIPLY the total Kcal by 1.125 (add a 12.5% safety buffer to ensure the user stays in a caloric deficit). Keep Protein, Fat, and Carbs exact.
5. Quality Taxonomy (tags):
   - Choose 'whole_food' (natural, unprocessed/minimally processed) OR 'ultra_processed' (fast food, chips, candy, industrial sausages).
   - Choose 'solid' OR 'liquid' (shakes, smoothies, soups, drinks).
   - Choose 'fast_absorbing' (sweets, refined carbs, liquid whey) OR 'slow_absorbing' (meat, whole grains, eggs).
   - Include 'high_sodium' if the meal contains salty sauces, cured meats, fast food, or pickles.
6. Micronutrients & Amino Acids Estimation:
   - Provide realistic estimates for key micronutrients: fiber_g, sodium_mg, potassium_mg, vitamin_c_mg, iron_mg, calcium_mg.
   - For meals containing protein, estimate amino_acids: leucine_g and total bcaa_g (leucine + isoleucine + valine).

Output ONLY a valid JSON object.
Expected format:
{
  "meal_name": "Short descriptive name in Ukrainian",
  "kcal": 450, 
  "protein": 35,
  "fat": 12,
  "carbs": 50,
  "weight_g": 350,
  "confidence": 85,
  "tags": ["whole_food", "solid", "slow_absorbing"],
  "micronutrients": {
    "fiber_g": 6.5,
    "sodium_mg": 520,
    "potassium_mg": 410,
    "vitamin_c_mg": 12,
    "iron_mg": 2.8,
    "calcium_mg": 85
  },
  "amino_acids": {
    "bcaa_g": 6.5,
    "leucine_g": 2.9
  }
}`;

// Helper function for Telegram requests with fallback to plain text
async function sendTg(method: string, payload: any) {
  try {
    const res = await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/${method}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error(`sendTg failed (${method}): ${res.status} ${res.statusText} - ${errText}`);
      if (payload.parse_mode && (errText.includes("can't parse entities") || res.status === 400)) {
        console.log("Resending sendTg without parse_mode...");
        const fallbackPayload = { ...payload };
        delete fallbackPayload.parse_mode;
        await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/${method}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(fallbackPayload)
        });
      }
    }
  } catch (err) {
    console.error(`sendTg network error (${method}):`, err);
  }
}

// Gemini request with automatic fallback between models
async function generateMealJSON(promptData: any[]): Promise<any> {
  const models = ["gemini-3.8-flash", "gemini-2.5-flash", "gemini-3.6-flash"];
  let lastError: any = null;

  for (const modelName of models) {
    try {
      console.log(`Calling model: ${modelName}...`);
      const model = genAI.getGenerativeModel({
        model: modelName,
        generationConfig: { responseMimeType: "application/json" }
      });
      const result = await model.generateContent(promptData);
      let responseText = result.response.text().trim();
      if (responseText.startsWith("```")) {
        responseText = responseText.replace(/^```(?:json)?\n?/i, "").replace(/\n?```$/i, "").trim();
      }
      return JSON.parse(responseText);
    } catch (err: any) {
      console.warn(`Model ${modelName} returned an error:`, err?.message || err);
      lastError = err;
    }
  }
  throw lastError || new Error("All Gemini models are unavailable");
}

// Date shift logic (night shifts + day offset)
function getDietaryDate(date = new Date(), offsetDays = 0) {
  const adjusted = new Date(date);
  adjusted.setHours(adjusted.getHours() - 4); // Night shifts
  if (offsetDays !== 0) {
    adjusted.setDate(adjusted.getDate() + offsetDays);
  }
  return adjusted.toISOString().split('T')[0];
}

// Generate statistics message with weight and analysis
async function getStatsPayload(userId: number, targetDate: string) {
  // 1. Meals
  const { data: meals } = await supabase
    .from('meals')
    .select('*')
    .eq('user_id', userId)
    .eq('dietary_date', targetDate);

  // 2. Daily weight measurement
  let dayWeight: number | null = null;
  try {
    const { data: weightLogs } = await supabase
      .from('body_measurements')
      .select('weight_kg')
      .eq('user_id', userId)
      .eq('dietary_date', targetDate)
      .order('measured_at', { ascending: false })
      .limit(1);

    if (weightLogs && weightLogs.length > 0) {
      dayWeight = weightLogs[0].weight_kg;
    }
  } catch (_) { }

  let kcal = 0, p = 0, f = 0, c = 0;
  let fiber = 0, sodium = 0;
  let wholeFoodCount = 0, ultraCount = 0, hasHighSodium = false;
  let mealNames: string[] = [];

  if (meals) {
    meals.forEach((m: any) => {
      kcal += Number(m.kcal) || 0;
      p += Number(m.protein) || 0;
      f += Number(m.fat) || 0;
      c += Number(m.carbs) || 0;
      mealNames.push(m.meal_name);

      const micro = m.micronutrients || {};
      fiber += Number(micro.fiber_g) || 0;
      sodium += Number(micro.sodium_mg) || 0;

      const tags = Array.isArray(m.tags) ? m.tags : [];
      if (tags.includes('whole_food')) wholeFoodCount++;
      if (tags.includes('ultra_processed')) ultraCount++;
      if (tags.includes('high_sodium')) hasHighSodium = true;
    });
  }

  // Recommendations block
  const recs: string[] = [];
  if (meals && meals.length > 0) {
    if (p < 100) {
      recs.push(`• 🥩 **Білок:** Бажано додати більше м'яса, риби, яєць або сиру для захисту м'язів.`);
    } else {
      recs.push(`• 🥩 **Білок:** Норму виконано (${Math.round(p)}г) — м'язи під надійним захистом.`);
    }

    if (fiber < 20) {
      recs.push(`• 🌾 **Клітковина:** Малувато — додайте свіжих овочів, зелені або ягід для травлення.`);
    }

    if (sodium > 2300 || hasHighSodium) {
      recs.push(`• 🧂 **Водний баланс:** Були солоні або перероблені страви — завтра очікується тимчасова затримка води. Це не жир!`);
    }

    if (ultraCount > 0) {
      recs.push(`• 🥗 **Якість продуктів:** Було ${ultraCount} ультраперероблених страв. Більше цільної їжі прискорить спалювання калорій.`);
    }

    if (kcal > 2200) {
      recs.push(`• 💡 **Де зекономити:** Зменшіть кількість доданої олії, соусів або рідких калорій.`);
    }
  } else {
    recs.push("• ℹ️ Записів їжі за цей день ще немає.");
  }

  const weightLine = dayWeight !== null
    ? `⚖️ Вага за день: **${dayWeight} кг**\n`
    : `⚖️ Вага за день: *не записана (введіть /w <вага>)*\n`;

  const text = `📊 **Статистика за ${targetDate}**\n\n` +
    weightLine +
    `🔥 Калорії: **${Math.round(kcal)} ккал**\n` +
    `🥩 Білки: **${Math.round(p)}г** | 🥑 Жири: **${Math.round(f)}г** | 🍞 Вуглеводи: **${Math.round(c)}г**\n\n` +
    `🍽 **З'їдено:** ${mealNames.length ? mealNames.join(', ') : 'Нічого 텅'}\n\n` +
    `🧠 **Аналіз раціону та поради:**\n` +
    recs.join('\n');

  const curr = new Date(targetDate);
  const prev = new Date(curr); prev.setDate(prev.getDate() - 1);
  const next = new Date(curr); next.setDate(next.getDate() + 1);

  return {
    text,
    parse_mode: 'Markdown',
    reply_markup: {
      inline_keyboard: [[
        { text: "⬅️", callback_data: `stats_${prev.toISOString().split('T')[0]}` },
        { text: "➡️", callback_data: `stats_${next.toISOString().split('T')[0]}` }
      ]]
    }
  };
}

const processedUpdates = new Set<number>();

async function handleUpdate(update: any) {
  try {
    // 1. BUTTON PROCESSING (Statistics scrolling)
    if (update.callback_query) {
      const cb = update.callback_query;
      if (cb.from.id !== ALLOWED_USER_ID) return;

      if (cb.data.startsWith('stats_')) {
        const targetDate = cb.data.split('_')[1];
        const payload = await getStatsPayload(cb.from.id, targetDate);
        await sendTg('editMessageText', { chat_id: cb.message.chat.id, message_id: cb.message.message_id, ...payload });
      }
      await sendTg('answerCallbackQuery', { callback_query_id: cb.id });
      return;
    }

    // 2. MESSAGE PROCESSING
    const msg = update.message;
    if (!msg || msg.chat.id !== ALLOWED_USER_ID) return;
    const chatId = msg.chat.id;
    const text = msg.text ? msg.text.trim() : "";

    // 0. /start command
    if (text === '/start') {
      await sendTg('sendMessage', {
        chat_id: chatId,
        text: "👋 **Вітаю у Lifecore!**\n\n" +
          "📸 **Їжа:** просто надішліть фото або опис страви текстом.\n" +
          "⚖️ **Вага:** кнопка «Записати вагу» або просто введіть число (наприклад `76.2`).\n" +
          "📅 **Вчора:** кнопка «Запис за вчора» для внесення страв за минулий день.\n" +
          "📊 **Статистика:** перегляд денного звіту та порад нутриціолога.",
        parse_mode: 'Markdown',
        reply_markup: MAIN_KEYBOARD
      });
      return;
    }

    // 1. /stats command or "📊 Статистика" button
    if (text === '/stats' || text === '📊 Статистика') {
      const payload = await getStatsPayload(chatId, getDietaryDate());
      await sendTg('sendMessage', { chat_id: chatId, ...payload });
      return;
    }

    // 2. "⚖️ Записати вагу" button
    if (text === '⚖️ Записати вагу') {
      await sendTg('sendMessage', {
        chat_id: chatId,
        text: "⚖️ Введіть ваше значення ваги у кг (наприклад: `76.2`):",
        parse_mode: 'Markdown',
        reply_markup: {
          force_reply: true,
          input_field_placeholder: "76.2"
        }
      });
      return;
    }

    // 3. "📅 Запис за вчора" button
    if (text === '📅 Запис за вчора') {
      await sendTg('sendMessage', {
        chat_id: chatId,
        text: "📅 Надішліть фото або опис страви, яку ви з'їли вчора:",
        reply_markup: {
          force_reply: true,
          input_field_placeholder: "Опис страви за вчора..."
        }
      });
      return;
    }

    // 4. Check for weight input:
    // Either via /w, or reply to weight prompt, or pure number from 30 to 350
    let detectedWeight: number | null = null;
    const wMatch = text.match(/^\/w(?:\s+([\d]+(?:[.,][\d]+)?))?(?:\s*kg)?$/i);
    if (wMatch && wMatch[1]) {
      detectedWeight = parseFloat(wMatch[1].replace(',', '.'));
    } else if (msg.reply_to_message?.text?.includes("ваги у кг")) {
      const numMatch = text.match(/^([\d]+(?:[.,][\d]+)?)/);
      if (numMatch) detectedWeight = parseFloat(numMatch[1].replace(',', '.'));
    } else {
      const pureNumMatch = text.match(/^([\d]{2,3}(?:[.,][\d]+)?)(?:\s*(?:кг|kg))?$/i);
      if (pureNumMatch) {
        const val = parseFloat(pureNumMatch[1].replace(',', '.'));
        if (val >= 30 && val <= 350) detectedWeight = val;
      }
    }

    if (detectedWeight !== null) {
      if (isNaN(detectedWeight) || detectedWeight < 30 || detectedWeight > 350) {
        await sendTg('sendMessage', { chat_id: chatId, text: "⚠️ Будь ласка, введіть реальну вагу від 30 до 350 кг.", reply_markup: MAIN_KEYBOARD });
        return;
      }

      const dietaryDate = getDietaryDate();

      // Dynamics from previous measurement
      const { data: prevData } = await supabase
        .from('body_measurements')
        .select('weight_kg')
        .eq('user_id', chatId)
        .order('measured_at', { ascending: false })
        .limit(1);

      let deltaText = "";
      if (prevData && prevData.length > 0) {
        const prevWeight = prevData[0].weight_kg;
        const diff = (detectedWeight - prevWeight).toFixed(1);
        if (Number(diff) > 0) {
          deltaText = `📈 Динаміка: **+${diff} кг** (з минулого заміру ${prevWeight} кг)`;
        } else if (Number(diff) < 0) {
          deltaText = `📉 Динаміка: **${diff} кг** (з минулого заміру ${prevWeight} кг)`;
        } else {
          deltaText = `⏸ Динаміка: **без змін** (${prevWeight} кг)`;
        }
      }

      await supabase.from('body_measurements').insert([{
        user_id: chatId,
        weight_kg: detectedWeight,
        dietary_date: dietaryDate,
        source: 'telegram_w'
      }]);

      let reply = `⚖️ **Вагу успішно записано: ${detectedWeight} кг**\n📅 Дієтична дата: \`${dietaryDate}\`\n`;
      if (deltaText) reply += `\n${deltaText}\n`;
      reply += `\n💡 *Пам'ятайте: 1 г глікогену затримує 3-4 г води. Щоденні коливання 1-2 кг є нормою водного балансу!*`;

      await sendTg('sendMessage', { chat_id: chatId, text: reply, parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD });
      return;
    }

    // 5. Food processing (text or photo + support for /y or reply to prompt)
    let textToAnalyze = msg.text || msg.caption || "";
    let offsetDays = 0;
    let isYesterday = false;

    if (textToAnalyze.trim().toLowerCase().startsWith('/y')) {
      offsetDays = -1;
      isYesterday = true;
      textToAnalyze = textToAnalyze.replace(/^\/y\s*/i, '').trim();
      if (!textToAnalyze && !msg.photo) return;
    } else if (msg.reply_to_message?.text?.includes("з'їли вчора")) {
      offsetDays = -1;
      isYesterday = true;
    } else if (msg.text?.startsWith('/')) {
      return;
    }

    const progressText = isYesterday ? "⏳ Рахую калорії за прийом (за вчора)..." : "⏳ Рахую калорії за прийом...";
    await sendTg('sendMessage', {
      chat_id: chatId,
      text: progressText
    });

    let promptData: any[] = [SYSTEM_PROMPT];
    let targetDate = getDietaryDate(new Date(), offsetDays);
    let photoDate = new Date(msg.forward_date ? msg.forward_date * 1000 : msg.date * 1000);

    // Working with photo, document or text
    let fileId: string | null = null;
    if (msg.photo && msg.photo.length > 0) {
      fileId = msg.photo[msg.photo.length - 1].file_id;
    } else if (msg.document) {
      const mime = msg.document.mime_type;
      if (mime && mime.startsWith('image/')) {
        fileId = msg.document.file_id;
      } else {
        await sendTg('sendMessage', { chat_id: chatId, text: "⚠️ Будь ласка, надішліть файл зображення." });
        return;
      }
    }

    if (fileId) {
      const fileRes = await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/getFile?file_id=${fileId}`);
      if (!fileRes.ok) throw new Error(`Telegram getFile failed: ${fileRes.statusText}`);
      const filePath = (await fileRes.json()).result.file_path;

      const imageRes = await fetch(`https://api.telegram.org/file/bot${TELEGRAM_TOKEN}/${filePath}`);
      if (!imageRes.ok) throw new Error(`Telegram image download failed: ${imageRes.statusText}`);
      const imageBuffer = await imageRes.arrayBuffer();
      
      try {
        const tags = ExifReader.load(imageBuffer);
        const dateStr = tags['DateTimeOriginal']?.description || tags['Creation Date']?.description || tags['CreateDate']?.description;
        if (dateStr) {
          // Convert "YYYY:MM:DD HH:MM:SS" to "YYYY-MM-DD HH:MM:SS" for proper parsing
          const isoStr = dateStr.replace(/^(\d{4}):(\d{2}):(\d{2})/, '$1-$2-$3');
          const parsed = new Date(isoStr);
          if (!isNaN(parsed.getTime())) {
            photoDate = parsed;
          }
        }
      } catch (e: any) {
        console.log("ExifReader parsing error:", e.message);
      }
      
      targetDate = getDietaryDate(photoDate, offsetDays);

      const base64Image = base64Encode(new Uint8Array(imageBuffer));

      const caption = textToAnalyze ? `\nDescription: ${textToAnalyze}` : "";
      const actualMime = msg.document?.mime_type || "image/jpeg";
      promptData = [SYSTEM_PROMPT + caption, { inlineData: { data: base64Image, mimeType: actualMime } }];
    } else if (textToAnalyze) {
      promptData = [SYSTEM_PROMPT, `Description: ${textToAnalyze}`];
    } else {
      return;
    }

    const meal = await generateMealJSON(promptData);

    // Writing to Supabase with extended fields
    const { error: dbError } = await supabase.from('meals').insert([{
      user_id: chatId,
      meal_name: meal.meal_name,
      kcal: meal.kcal,
      protein: meal.protein,
      fat: meal.fat,
      carbs: meal.carbs,
      weight_g: meal.weight_g,
      confidence: meal.confidence,
      tags: meal.tags || [],
      micronutrients: meal.micronutrients || {},
      amino_acids: meal.amino_acids || {},
      dietary_date: targetDate,
      created_at: photoDate.toISOString(),
      telegram_file_id: fileId
    }]);

    if (dbError) {
      console.error("DB write error:", dbError);
      throw new Error("Failed to save to database");
    }

    const dateMarker = isYesterday ? "📅 **[Записано за вчора]**\n" : "";
    const reply = `${dateMarker}🍽 **${meal.meal_name}**\n\n` +
      `🔥 Калорії: **${meal.kcal} ккал**\n` +
      `🥩 Білки: **${meal.protein}г** | 🥑 Жири: **${meal.fat}г** | 🍞 Вуглеводи: **${meal.carbs}г**\n` +
      `⚖️ Вага: ~**${meal.weight_g}г**\n` +
      `🤖 Впевненість: ${meal.confidence}%`;

    await sendTg('sendMessage', {
      chat_id: chatId,
      text: reply,
      parse_mode: 'Markdown',
      reply_markup: MAIN_KEYBOARD
    });

  } catch (e: any) {
    console.error("handleUpdate execution error:", e);
    const targetChatId = update?.message?.chat?.id || ALLOWED_USER_ID;
    const errorDetails = e?.message ? `\nДеталі: ${e.message}` : "";
    await sendTg('sendMessage', {
      chat_id: targetChatId,
      text: `❌ Упс, сталася помилка під час обробки.${errorDetails}\nБудь ласка, спробуйте ще раз.`
    }).catch(() => { });
  }
}

serve(async (req: Request) => {
  try {
    const update = await req.json();

    if (update.update_id) {
      if (processedUpdates.has(update.update_id)) {
        console.log(`Update ${update.update_id} is already being processed, skipping.`);
        return new Response("OK", { status: 200 });
      }
      processedUpdates.add(update.update_id);

      if (processedUpdates.size > 100) {
        const iterator = processedUpdates.values();
        const nextVal = iterator.next().value;
        if (nextVal !== undefined) {
          processedUpdates.delete(nextVal);
        }
      }
    }

    await handleUpdate(update);
    return new Response("OK", { status: 200 });

  } catch (e) {
    console.error("Request retrieval error:", e);
    return new Response("OK", { status: 200 });
  }
});