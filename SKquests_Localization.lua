-- SKquests Language Module
-- Supports English and Spanish

SKquests_Localization = {
    currentLanguage = "enUS",  -- default language
    
    languages = {
        enUS = true,
        esES = true,
    }
}

-- English translations
SKquests_Localization.enUS = {
    QUEST_TITLE = "Quest",
    OBJECTIVES = "Objectives",
    WOWHEAD = "Wowhead",
    STEP = "Step",
    OF = "of",
    NEXT_QUEST = "Next Quest",
    PREVIOUS_QUEST = "Previous Quest",
    QUEST_OBJECTIVES = "Quest Objectives",
    WHAT_TO_DO = "What to do",
    LANGUAGE = "Language",
    SETTINGS = "Settings",
    ACCEPT = "Accept",
    CLOSE = "Close",
    TRACK = "Track",
    HELP = "Help",
    COMMANDS = "Commands",
    NOT_ASSIGNED = "Not assigned",
    NO_INFORMATION = "No information available",
    CLICK_FOR_WOWHEAD = "Click to open on Wowhead",
    QUESTIE_STATUS = "Questie Status",
    SHOW_TITLE = "Show quest title",
    SHOW_IMAGE = "Show map image",
    AUTO_MINIMIZE = "Auto minimize in combat",
    QUESTIE_INTEGRATION = "Questie integration",
    IMAGE_SIZE = "Image size",
    TEXT_SIZE = "Text size",
    OPACITY = "Opacity",
    GENERAL = "General",
    APPEARANCE = "Appearance",
    INFORMATION = "Information",
    SMALL = "Small",
    MEDIUM = "Medium",
    LARGE = "Large",
    NORMAL = "Normal",
}

-- Spanish translations
SKquests_Localization.esES = {
    QUEST_TITLE = "Misión",
    OBJECTIVES = "Objetivos",
    WOWHEAD = "Wowhead",
    STEP = "Paso",
    OF = "de",
    NEXT_QUEST = "Siguiente Misión",
    PREVIOUS_QUEST = "Misión Anterior",
    QUEST_OBJECTIVES = "Objetivos de la Misión",
    WHAT_TO_DO = "Qué hacer",
    LANGUAGE = "Idioma",
    SETTINGS = "Configuración",
    ACCEPT = "Aceptar",
    CLOSE = "Cerrar",
    TRACK = "Rastrear",
    HELP = "Ayuda",
    COMMANDS = "Comandos",
    NOT_ASSIGNED = "No asignado",
    NO_INFORMATION = "Información no disponible",
    CLICK_FOR_WOWHEAD = "Clic para abrir en Wowhead",
    QUESTIE_STATUS = "Estado Questie",
    SHOW_TITLE = "Mostrar título de misión",
    SHOW_IMAGE = "Mostrar imagen del mapa",
    AUTO_MINIMIZE = "Minimizar automático en combate",
    QUESTIE_INTEGRATION = "Integración con Questie",
    IMAGE_SIZE = "Tamaño de imagen",
    TEXT_SIZE = "Tamaño de texto",
    OPACITY = "Opacidad",
    GENERAL = "General",
    APPEARANCE = "Apariencia",
    INFORMATION = "Información",
    SMALL = "Pequeño",
    MEDIUM = "Mediano",
    LARGE = "Grande",
    NORMAL = "Normal",
}

function SKquests_Localization:SetLanguage(lang)
    if self.languages[lang] then
        self.currentLanguage = lang
        return true
    end
    return false
end

function SKquests_Localization:Get(key)
    local translations = self[self.currentLanguage]
    if translations and translations[key] then
        return translations[key]
    end
    -- Fallback to English if translation missing
    local englishTranslations = self.enUS
    if englishTranslations and englishTranslations[key] then
        return englishTranslations[key]
    end
    return key
end

-- Shorthand function
function L(key)
    return SKquests_Localization:Get(key)
end
