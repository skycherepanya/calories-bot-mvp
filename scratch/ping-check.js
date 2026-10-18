require('dotenv').config();
const https = require('https');
const { createClient } = require('@supabase/supabase-js');
const { GoogleGenerativeAI } = require('@google/generative-ai');

function makeRequest(url, options = {}) {
    return new Promise((resolve, reject) => {
        const req = https.request(url, options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve({ statusCode: res.statusCode, headers: res.headers, body: JSON.parse(data) });
                } catch (e) {
                    resolve({ statusCode: res.statusCode, headers: res.headers, rawBody: data });
                }
            });
        });
        req.on('error', reject);
        if (options.body) {
            req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
        }
        req.end();
    });
}

async function runPing() {
    console.log('=== STARTING LIFECORE SYSTEM PING ===\n');

    const results = {
        env: {},
        telegram: {},
        supabase: {},
        gemini: {},
        webhook: {}
    };

    // 1. ENV VARIABLES
    const requiredEnv = ['TELEGRAM_BOT_TOKEN', 'ALLOWED_USER_ID', 'GEMINI_API_KEY', 'SUPABASE_URL', 'SUPABASE_KEY'];
    for (const key of requiredEnv) {
        results.env[key] = !!process.env[key];
    }
    console.log('[1/4] Environment variables check:', results.env);

    // 2. TELEGRAM API
    if (process.env.TELEGRAM_BOT_TOKEN) {
        try {
            const meRes = await makeRequest(`https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/getMe`);
            if (meRes.body && meRes.body.ok) {
                results.telegram.bot = {
                    ok: true,
                    username: meRes.body.result.username,
                    first_name: meRes.body.result.first_name,
                    id: meRes.body.result.id
                };
            } else {
                results.telegram.bot = { ok: false, error: meRes.body };
            }

            const whRes = await makeRequest(`https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/getWebhookInfo`);
            if (whRes.body && whRes.body.ok) {
                results.telegram.webhook = whRes.body.result;
            } else {
                results.telegram.webhook = { ok: false, error: whRes.body };
            }
        } catch (err) {
            results.telegram.error = err.message;
        }
    }
    console.log('\n[2/4] Telegram Bot API check:');
    console.log('Bot:', results.telegram.bot);
    console.log('Webhook info:', results.telegram.webhook);

    // 3. SUPABASE DB
    if (process.env.SUPABASE_URL && process.env.SUPABASE_KEY) {
        try {
            const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

            // Ping meals
            const startMeals = Date.now();
            const { data: meals, error: mealsErr, count: mealsCount } = await supabase
                .from('meals')
                .select('id, meal_name, dietary_date, created_at', { count: 'exact' })
                .order('created_at', { ascending: false })
                .limit(1);
            const mealsLatency = Date.now() - startMeals;

            // Ping body_measurements
            const startWeight = Date.now();
            const { data: weight, error: weightErr, count: weightCount } = await supabase
                .from('body_measurements')
                .select('id, weight_kg, dietary_date, measured_at', { count: 'exact' })
                .order('measured_at', { ascending: false })
                .limit(1);
            const weightLatency = Date.now() - startWeight;

            results.supabase = {
                ok: !mealsErr && !weightErr,
                meals: {
                    latencyMs: mealsLatency,
                    count: mealsCount,
                    latest: meals ? meals[0] : null,
                    error: mealsErr ? mealsErr.message : null
                },
                body_measurements: {
                    latencyMs: weightLatency,
                    count: weightCount,
                    latest: weight ? weight[0] : null,
                    error: weightErr ? weightErr.message : null
                }
            };
        } catch (err) {
            results.supabase.error = err.message;
        }
    }
    console.log('\n[3/4] Supabase Database check:');
    console.log(JSON.stringify(results.supabase, null, 2));

    // 4. GEMINI API
    if (process.env.GEMINI_API_KEY) {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        results.gemini.models = {};

        const testModels = ["gemini-2.5-flash", "gemini-3.6-flash", "gemini-1.5-flash", "gemini-2.0-flash"];

        for (const modelName of testModels) {
            try {
                const startTime = Date.now();
                const model = genAI.getGenerativeModel({
                    model: modelName,
                    generationConfig: { responseMimeType: "application/json" }
                });
                const res = await model.generateContent("Return JSON: {\"status\": \"ok\", \"model\": \"" + modelName + "\"}");
                const text = res.response.text();
                results.gemini.models[modelName] = {
                    ok: true,
                    latencyMs: Date.now() - startTime,
                    response: JSON.parse(text)
                };
            } catch (err) {
                results.gemini.models[modelName] = {
                    ok: false,
                    error: err.message
                };
            }
        }
    }
    console.log('\n[4/4] Gemini Models check:');
    console.log(JSON.stringify(results.gemini, null, 2));

    // 5. WEBHOOK ENDPOINT TEST (if URL exists)
    if (results.telegram.webhook && results.telegram.webhook.url) {
        const whUrl = results.telegram.webhook.url;
        console.log(`\n[5/5] Testing Webhook URL: ${whUrl}`);
        try {
            const startWh = Date.now();
            const res = await makeRequest(whUrl, { method: 'GET' });
            results.webhook = {
                url: whUrl,
                latencyMs: Date.now() - startWh,
                statusCode: res.statusCode,
                body: res.body || res.rawBody
            };
        } catch (err) {
            results.webhook = { url: whUrl, error: err.message };
        }
        console.log('Webhook test result:', results.webhook);
    }

    console.log('\n=== PING COMPLETE ===');
}

runPing().catch(err => {
    console.error('Fatal ping error:', err);
});
