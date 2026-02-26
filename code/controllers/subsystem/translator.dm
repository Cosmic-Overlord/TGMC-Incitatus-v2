// Для перевода использовался локальный хост libretranslate
// https://ru.libretranslate.com/
// https://github.com/LibreTranslate/LibreTranslate

SUBSYSTEM_DEF(translator)
	name = "Translator"
	init_stage = INITSTAGE_EARLY
	flags = SS_NO_FIRE
	// Simple in-memory LRU cache for translations.
	var/list/translation_cache = list()
	var/list/translation_cache_order = list()
	var/translation_cache_max_entries = 1000

/datum/controller/subsystem/translator/proc/cache_key(text, source, target)
	return "[source]\t[target]\t[text]"

/datum/controller/subsystem/translator/proc/cache_get(text, source, target)
	var/key = cache_key(text, source, target)
	if(isnull(translation_cache[key]))
		return null
	translation_cache_order.Remove(key)
	translation_cache_order += key
	return translation_cache[key]

/datum/controller/subsystem/translator/proc/cache_set(text, source, target, translated)
	if(isnull(translated))
		return
	var/key = cache_key(text, source, target)
	if(!isnull(translation_cache[key]))
		translation_cache_order.Remove(key)
	translation_cache[key] = translated
	translation_cache_order += key
	while(length(translation_cache_order) > translation_cache_max_entries)
		var/oldest = translation_cache_order[1]
		translation_cache_order.Cut(1, 2)
		translation_cache -= oldest

/datum/controller/subsystem/translator/proc/translate(text, source = "auto", target = "en", silent = TRUE)

	// Проверка конфигурации
	var/base_url = CONFIG_GET(string/libretranslate_url)
	if(!base_url)
		if(!silent)
			to_chat(usr, span_warning("LibreTranslate URL not configured"))
		return null

	// Проверка длины текста (LibreTranslate обычно имеет лимит ~5000 символов)
	// var/max_length = CONFIG_GET(number/translation_max_length) || 5000
	var/max_length = 5000
	if(length_char(text) > max_length)
		if(!silent)
			to_chat(usr, span_warning("Text too long ([length_char(text)] > [max_length] characters)"))
		return null

	var/cached = cache_get(text, source, target)
	if(!isnull(cached))
		return cached

	// Формируем тело запроса
	var/list/request_data = list(
		"q" = text,
		"source" = source,
		"target" = target,
		"format" = "text"
	)

	var/api_key = CONFIG_GET(string/libretranslate_api_key)
	if(api_key)
		request_data["api_key"] = api_key

	// Отправка запроса
	var/datum/http_request/req = new()
	req.prepare(
		RUSTG_HTTP_METHOD_POST,
		"[base_url]/translate",
		json_encode(request_data),
		list("Content-Type" = "application/json")
	)
	req.begin_async()
	UNTIL(req.is_complete())
	var/datum/http_response/res = req.into_response()

	// Обработка ошибок HTTP
	if(res.errored || !res.body)
		if(!silent)
			to_chat(usr, span_warning("HTTP request failed: [res.error]"))
		return null

	// Обработка ошибок API
	if(res.status_code != 200)
		if(!silent)
			to_chat(usr, span_warning("Translation API error ([res.status_code]): [res.body]"))
		return null

	// Парсинг ответа
	try
		var/list/data = json_decode(res.body)
		var/translated = data["translatedText"]
		cache_set(text, source, target, translated)
		return translated

	catch(var/exception/e)
		if(!silent)
			to_chat(usr, span_warning("JSON parse error: [e]\nResponse: [res.body]"))
		return null
