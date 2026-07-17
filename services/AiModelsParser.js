.pragma library

function guessModelName(model) {
    const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
    let words = replaced.split(' ');
    words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`)
    words = words.map((word) => {
        return (word.charAt(0).toUpperCase() + word.slice(1))
    });
    if (words[words.length - 1] === "Latest") words.pop();
    else words[words.length - 1] = `(${words[words.length - 1]})`;
    const result = words.join(' ');
    return result;
}

function parseCustomProviderModels(responseJsonString, baseUrl, providerName) {
    try {
        if (!responseJsonString || responseJsonString.trim() === "") return [];
        const data = JSON.parse(responseJsonString);
        if (!data || !Array.isArray(data.data)) return [];
        let result = [];
        let sanitizedBaseUrl = baseUrl;
        if (sanitizedBaseUrl.endsWith("/")) {
            sanitizedBaseUrl = sanitizedBaseUrl.slice(0, -1);
        }
        data.data.forEach(model => {
            if (!model.id) return;
            result.push({
                name: guessModelName(model.id),
                model: model.id,
                description: `Online | Custom (${providerName}) | ${model.id}`,
                endpoint: sanitizedBaseUrl + "/chat/completions",
                requires_key: true,
                key_id: "custom_provider",
                api_format: "openai"
            });
        });
        return result;
    } catch (e) {
        return [];
    }
}
