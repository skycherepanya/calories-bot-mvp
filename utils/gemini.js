async function generateMealJSON(genAI, promptData) {
    const models = ["gemini-3.8-flash", "gemini-2.5-flash", "gemini-3.6-flash"];
    let lastError = null;

    for (const modelName of models) {
        try {
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
        } catch (err) {
            console.warn(`[Gemini] ${modelName} failed:`, err.message);
            lastError = err;
        }
    }
    throw lastError || new Error("All Gemini models failed");
}

module.exports = { generateMealJSON };
