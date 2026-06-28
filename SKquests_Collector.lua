-- SKquests_Collector.lua
  -- Recolector dinámico de datos para WotLK Classic (ChromieCraft)
  -- Captura automáticamente quests, recompensas e ítems del cliente en vivo
  -- y los almacena en SKquestsDB.collected / SKquestsDB.collectedItems

  local ADDON_NAME = "SKquests"
  SKquests = SKquests or {}
  local Collector = {}
  SKquests.Collector = Collector

  -- ── Estado interno ────────────────────────────────────────────────────────────
  Collector.quests       = {}   -- [questId] = { id, name, desc, logDesc, rewards, choiceRewards }
  Collector.items        = {}   -- [itemId]  = { id, name, link, rarity, ilvl, ... }
  Collector._pendingTitle = nil
  Collector._pendingDesc  = nil
  Collector._pendingObj   = nil
  local pendingItems = {}       -- itemIds a la espera de GET_ITEM_INFO_RECEIVED

  -- ── Helpers ───────────────────────────────────────────────────────────────────
  local function SaveDB()
    if SKquestsDB then
      SKquestsDB.collected      = Collector.quests
      SKquestsDB.collectedItems = Collector.items
    end
  end

  -- Busca el questId de una quest en el log por título exacto
  local function FindQuestIdByTitle(title)
    if not title then return nil end
    for i = 1, GetNumQuestLogEntries() do
      local t, _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
      if not isHeader and t == title then
        return questId
      end
    end
    return nil
  end

  -- Extrae el itemId de un itemLink ("item:12345:...")
  local function ItemIdFromLink(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
  end

  -- Guarda un ítem en Collector.items (async-safe)
  local function CaptureItem(itemId)
    if not itemId or Collector.items[itemId] then return end
    local name, link, rarity, ilvl, minLvl, itype, isubtype, _, equipLoc, texture, sellPrice =
      GetItemInfo(itemId)
    if name then
      Collector.items[itemId] = {
        id        = itemId,
        name      = name,
        link      = link,
        rarity    = rarity,
        ilvl      = ilvl,
        minLvl    = minLvl,
        itype     = itype,
        isubtype  = isubtype,
        equipLoc  = equipLoc,
        texture   = texture,
        sellPrice = sellPrice,
      }
    else
      -- El cliente no tiene el ítem en caché; se reintentará al recibir GET_ITEM_INFO_RECEIVED
      pendingItems[itemId] = true
      GetItemInfo(itemId)  -- dispara GET_ITEM_INFO_RECEIVED cuando llegue
    end
  end

  -- Lee las recompensas visibles en el diálogo de quest y las guarda
  local function CaptureCurrentRewards(questId, questTitle)
    if not questId then return end
    local entry = Collector.quests[questId] or { id = questId, name = questTitle }

    -- Recompensas fijas
    local numFixed = GetNumQuestRewards()
    if numFixed and numFixed > 0 then
      local already = {}
      for _, r in ipairs(entry.rewards or {}) do already[r.id] = true end
      entry.rewards = entry.rewards or {}
      for i = 1, numFixed do
        local itemName, _, qty = GetQuestItemInfo("reward", i)
        local link   = GetQuestItemLink and GetQuestItemLink("reward", i)
        local itemId = ItemIdFromLink(link)
        if itemId and not already[itemId] then
          table.insert(entry.rewards, { id = itemId, qty = qty or 1, name = itemName })
          CaptureItem(itemId)
          already[itemId] = true
        end
      end
    end

    -- Recompensas a elección
    local numChoice = GetNumQuestChoices()
    if numChoice and numChoice > 0 then
      local already = {}
      for _, r in ipairs(entry.choiceRewards or {}) do already[r.id] = true end
      entry.choiceRewards = entry.choiceRewards or {}
      for i = 1, numChoice do
        local itemName, _, qty = GetQuestItemInfo("choice", i)
        local link   = GetQuestItemLink and GetQuestItemLink("choice", i)
        local itemId = ItemIdFromLink(link)
        if itemId and not already[itemId] then
          table.insert(entry.choiceRewards, { id = itemId, qty = qty or 1, name = itemName })
          CaptureItem(itemId)
          already[itemId] = true
        end
      end
    end

    Collector.quests[questId] = entry
    SaveDB()
  end

  -- ── Frame de eventos ──────────────────────────────────────────────────────────
  local frame = CreateFrame("Frame", "SKquestsCollectorFrame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("QUEST_DETAIL")
  frame:RegisterEvent("QUEST_PROGRESS")
  frame:RegisterEvent("QUEST_COMPLETE")
  frame:RegisterEvent("QUEST_ACCEPTED")
  frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

  frame:SetScript("OnEvent", function(self, event, arg1, arg2)

    -- ── ADDON_LOADED: inicializar desde SavedVariables ────────────────────────
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
      if not SKquestsDB then SKquestsDB = {} end
      if not SKquestsDB.collected      then SKquestsDB.collected      = {} end
      if not SKquestsDB.collectedItems then SKquestsDB.collectedItems = {} end
      Collector.quests = SKquestsDB.collected
      Collector.items  = SKquestsDB.collectedItems

    -- ── QUEST_DETAIL: jugador abre diálogo de quest con NPC ──────────────────
    elseif event == "QUEST_DETAIL" then
      local title = GetTitleText and GetTitleText() or ""
      local desc  = GetQuestText  and GetQuestText()  or ""
      local obj   = GetObjectiveText and GetObjectiveText() or ""
      Collector._pendingTitle = title
      Collector._pendingDesc  = desc
      Collector._pendingObj   = obj

      -- Intentar capturar ya si la quest ya está en el log (repetición)
      local questId = FindQuestIdByTitle(title)
      if questId then
        local entry = Collector.quests[questId] or { id = questId }
        entry.name    = title
        entry.desc    = entry.desc    == "" and desc or (entry.desc or desc)
        entry.logDesc = entry.logDesc == "" and obj  or (entry.logDesc or obj)
        Collector.quests[questId] = entry
        CaptureCurrentRewards(questId, title)
      end

    -- ── QUEST_PROGRESS: jugador habla con NPC para entregar quest ─────────────
    elseif event == "QUEST_PROGRESS" then
      local title = GetTitleText and GetTitleText() or ""
      if title ~= "" then
        local questId = FindQuestIdByTitle(title)
        if questId then
          local entry = Collector.quests[questId] or { id = questId, name = title }
          Collector.quests[questId] = entry
          SaveDB()
        end
      end

    -- ── QUEST_COMPLETE: pantalla de recompensas ───────────────────────────────
    elseif event == "QUEST_COMPLETE" then
      local title = GetTitleText and GetTitleText() or Collector._pendingTitle or ""
      local questId = FindQuestIdByTitle(title)
      if questId then
        CaptureCurrentRewards(questId, title)
      end

    -- ── QUEST_ACCEPTED: quest aceptada y ya en el log ─────────────────────────
    -- En WotLK 3.3.5a: arg1 = logIndex, arg2 = questId
    elseif event == "QUEST_ACCEPTED" then
      local questId = arg2  -- puede ser nil en algunos builds
      if not questId or questId == 0 then
        questId = FindQuestIdByTitle(Collector._pendingTitle)
      end
      if questId and questId > 0 then
        local entry = Collector.quests[questId] or { id = questId }
        if Collector._pendingTitle and Collector._pendingTitle ~= "" then
          entry.name = Collector._pendingTitle
        end
        if Collector._pendingDesc and Collector._pendingDesc ~= "" then
          entry.desc = Collector._pendingDesc
        end
        if Collector._pendingObj and Collector._pendingObj ~= "" then
          entry.logDesc = Collector._pendingObj
        end
        Collector.quests[questId] = entry
        CaptureCurrentRewards(questId, entry.name)
      end
      Collector._pendingTitle = nil
      Collector._pendingDesc  = nil
      Collector._pendingObj   = nil

    -- ── GET_ITEM_INFO_RECEIVED: datos de ítem llegaron async ─────────────────
    elseif event == "GET_ITEM_INFO_RECEIVED" then
      local itemId, success = arg1, arg2
      if success and itemId and pendingItems[itemId] then
        pendingItems[itemId] = nil
        CaptureItem(itemId)
        SaveDB()
      end
    end
  end)

  -- ── API pública ───────────────────────────────────────────────────────────────

  -- Enriquece una entrada de SKquests_DetailDB[id] con datos recolectados.
  -- Llena campos vacíos y fusiona recompensas desconocidas (ítems custom del servidor).
  function Collector:EnrichQuestEntry(q)
    if not q then return q end
    local cq = q.id and self.quests[q.id]
    if not cq then return q end

    -- Descripción / objetivo
    if (not q.desc    or q.desc    == "") and cq.desc    and cq.desc    ~= "" then q.desc    = cq.desc    end
    if (not q.logDesc or q.logDesc == "") and cq.logDesc and cq.logDesc ~= "" then q.logDesc = cq.logDesc end

    -- Recompensas fijas: fusionar ítems nuevos (ej. custom del servidor)
    if cq.rewards and #cq.rewards > 0 then
      if not q.rewards or #q.rewards == 0 then
        q.rewards = cq.rewards
      else
        local existing = {}
        for _, r in ipairs(q.rewards) do existing[r.id or r.itemID] = true end
        for _, r in ipairs(cq.rewards) do
          if not existing[r.id] then
            table.insert(q.rewards, r)
            existing[r.id] = true
          end
        end
      end
    end

    -- Recompensas a elección: si DB no tiene ninguna, usar las recolectadas
    if cq.choiceRewards and #cq.choiceRewards > 0 then
      if not q.choiceRewards or #q.choiceRewards == 0 then
        q.choiceRewards = cq.choiceRewards
      else
        local existing = {}
        for _, r in ipairs(q.choiceRewards) do existing[r.id] = true end
        for _, r in ipairs(cq.choiceRewards) do
          if not existing[r.id] then
            table.insert(q.choiceRewards, r)
            existing[r.id] = true
          end
        end
      end
    end

    return q
  end

  -- Devuelve la entrada recolectada para un questId, o nil
  function Collector:GetQuestData(questId)
    return questId and self.quests[questId] or nil
  end

  -- Devuelve datos recolectados de un ítem, o nil
  function Collector:GetItemData(itemId)
    return itemId and self.items[itemId] or nil
  end

  -- Devuelve cuántas quests y ítems hay recolectados
  function Collector:Stats()
    local qCount, iCount = 0, 0
    for _ in pairs(self.quests) do qCount = qCount + 1 end
    for _ in pairs(self.items)  do iCount = iCount + 1 end
    return qCount, iCount
  end
  
  -- ════════════════════════════════════════════════════════════════════════════
  --  RECOLECTOR DE DATOS HARDCORE / SERVIDOR  (SKQ_CollectedData)
  --  Captura automatica para portar contenido custom del servidor:
  --   - quests:  id, nombre, nivel, desc, objetivos, zona, nivel del jugador, isCustom
  --   - rewards: XP REAL medida (UnitXP antes/despues de entregar), oro
  --   - npcs:    NPC de inicio y fin con ID, nombre, zona y coordenadas
  --   - deaths:  muertes por mision (alimentado tambien por SKquests_Risk.lua)
  --  Comando: /skq export  ->  vuelca el resumen y guarda en SavedVariables.
  -- ════════════════════════════════════════════════════════════════════════════
  do
    local function EnsureCD()
      if not SKQ_CollectedData then SKQ_CollectedData = {} end
      SKQ_CollectedData.quests  = SKQ_CollectedData.quests  or {}
      SKQ_CollectedData.rewards = SKQ_CollectedData.rewards or {}
      SKQ_CollectedData.npcs    = SKQ_CollectedData.npcs    or {}
      SKQ_CollectedData.deaths  = SKQ_CollectedData.deaths  or {}
      return SKQ_CollectedData
    end

    -- Extrae el ID de NPC de un GUID de criatura de 3.3.5a (best-effort).
    local function NpcIdFromGuid(guid)
      if not guid or guid == "" then return nil end
      local id = tonumber(guid:sub(9, 12), 16)
      if id and id > 0 then return id end
      return nil
    end

    -- Coordenadas del jugador (0-100) en la zona actual; nil si no disponibles.
    local function PlayerCoords()
      if SetMapToCurrentZone then SetMapToCurrentZone() end
      if not GetPlayerMapPosition then return nil, nil end
      local x, y = GetPlayerMapPosition("player")
      if not x or x == 0 and y == 0 then return nil, nil end
      return math.floor(x * 1000) / 10, math.floor(y * 1000) / 10
    end

    -- Datos del NPC con el que se interactua ("npc"): id, nombre, zona y coords.
    local function CurrentNpcInfo()
      local name = UnitName and UnitName("npc")
      if not name then return nil end
      local guid = UnitGUID and UnitGUID("npc")
      local x, y = PlayerCoords()
      return {
        id      = NpcIdFromGuid(guid),
        guid    = guid,
        name    = name,
        zone    = (GetRealZoneText and GetRealZoneText()) or "",
        subZone = (GetSubZoneText and GetSubZoneText()) or "",
        x       = x,
        y       = y,
      }
    end

    -- Registra/actualiza un NPC en SKQ_CollectedData.npcs y lo enlaza a la mision.
    local function RegisterNpc(npc, questId, role)
      if not npc or not questId then return end
      local cd = EnsureCD()
      local key = npc.id or npc.name
      if not key then return end
      local rec = cd.npcs[key] or {
        id = npc.id, name = npc.name, zone = npc.zone, subZone = npc.subZone,
        x = npc.x, y = npc.y, gives = {}, ends = {},
      }
      rec.name    = rec.name    or npc.name
      rec.zone    = rec.zone    or npc.zone
      rec.subZone = rec.subZone or npc.subZone
      rec.x       = rec.x       or npc.x
      rec.y       = rec.y       or npc.y
      if role == "gives" then rec.gives[questId] = true
      elseif role == "ends" then rec.ends[questId] = true end
      cd.npcs[key] = rec
    end

    -- ¿Es una mision custom del servidor? (no esta en la DB enviada con el addon)
    local function IsCustomQuest(questId)
      if not SKquests_DetailDB then return true end
      return SKquests_DetailDB[questId] == nil
    end

    local pendingStartNpc = nil   -- NPC capturado en QUEST_DETAIL (inicio)
    local pendingTitle    = nil
    local pendingXP       = nil   -- { qid, xpBefore, maxBefore, levelBefore }

    local function FindQuestIdByTitle(title)
      if not title then return nil end
      local n = (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
      for i = 1, n do
        local t, _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
        if not isHeader and t == title then return questId end
      end
      return nil
    end

    local hc = CreateFrame("Frame", "SKquestsHardcoreCollector")
    hc:RegisterEvent("ADDON_LOADED")
    hc:RegisterEvent("QUEST_DETAIL")
    hc:RegisterEvent("QUEST_ACCEPTED")
    hc:RegisterEvent("QUEST_COMPLETE")
    hc:RegisterEvent("QUEST_TURNED_IN")

    hc:SetScript("OnEvent", function(_, event, arg1, arg2)
      if event == "ADDON_LOADED" then
        if arg1 == "SKquests" then EnsureCD() end
        return
      end

      local cd = EnsureCD()

      if event == "QUEST_DETAIL" then
        -- El jugador abre el dialogo de oferta de un NPC: capturar NPC de inicio.
        pendingTitle    = (GetTitleText and GetTitleText()) or ""
        pendingStartNpc = CurrentNpcInfo()

      elseif event == "QUEST_ACCEPTED" then
        -- 3.3.5a: arg1 = logIndex, arg2 = questId
        local questId = arg2
        if (not questId or questId == 0) and pendingTitle then
          questId = FindQuestIdByTitle(pendingTitle)
        end
        if questId and questId > 0 then
          local title, level, _, _, _, _, _, _, _ = nil
          -- Releer datos desde el log para asegurar nivel/objetivos correctos
          local logIdx = arg1
          if logIdx and GetQuestLogTitle then
            local t, lv = GetQuestLogTitle(logIdx)
            title = t; level = lv
          end
          local q = cd.quests[questId] or { id = questId }
          q.name        = q.name or title or pendingTitle
          q.level       = level or q.level
          q.desc        = (GetQuestText and GetQuestText()) or q.desc
          q.objectives  = (GetObjectiveText and GetObjectiveText()) or q.objectives
          q.zone        = (GetRealZoneText and GetRealZoneText()) or q.zone
          q.subZone     = (GetSubZoneText and GetSubZoneText()) or q.subZone
          q.playerLevel = (UnitLevel and UnitLevel("player")) or q.playerLevel
          q.isCustom    = IsCustomQuest(questId)
          q.accepted    = (time and time()) or q.accepted
          if pendingStartNpc then
            q.startNpc = pendingStartNpc
            RegisterNpc(pendingStartNpc, questId, "gives")
          end
          cd.quests[questId] = q
        end
        pendingStartNpc = nil
        pendingTitle    = nil

      elseif event == "QUEST_COMPLETE" then
        -- Pantalla de recompensas con el NPC de entrega: capturar NPC fin + XP base.
        local title   = (GetTitleText and GetTitleText()) or pendingTitle or ""
        local questId = FindQuestIdByTitle(title)
        if questId then
          local endNpc = CurrentNpcInfo()
          if endNpc then
            local q = cd.quests[questId] or { id = questId, name = title }
            q.endNpc = endNpc
            cd.quests[questId] = q
            RegisterNpc(endNpc, questId, "ends")
          end
          -- Medir XP real: guardar valores ANTES de entregar.
          -- El dinero se lee aqui (pantalla de recompensa abierta); tras la
          -- entrega GetRewardMoney() ya no es fiable.
          pendingXP = {
            qid         = questId,
            xpBefore    = (UnitXP and UnitXP("player")) or 0,
            maxBefore   = (UnitXPMax and UnitXPMax("player")) or 0,
            levelBefore = (UnitLevel and UnitLevel("player")) or 0,
            money       = (GetRewardMoney and GetRewardMoney()) or nil,
            armed       = false,
          }
        end

      elseif event == "QUEST_TURNED_IN" then
        -- arg1 = questId (3.3.5a). Confirma la entrega real: solo entonces
        -- programamos la lectura de XP. NO medimos en PLAYER_XP_UPDATE
        -- arbitrarios para no atribuir XP de mobs/exploracion a la quest.
        local qid = arg1
        if pendingXP and (not qid or qid == 0 or qid == pendingXP.qid) then
          pendingXP.armed = true
          pendingXP.t     = 0
        elseif pendingXP and qid and qid ~= pendingXP.qid then
          -- Entrega de otra quest sin recompensa capturada: descartar estado.
          pendingXP = nil
        end
      end
    end)

    -- Finalizacion diferida de XP: tras confirmar QUEST_TURNED_IN esperamos un
    -- breve instante para que el servidor aplique la XP de recompensa y luego
    -- calculamos la diferencia real. Esto resuelve tanto el caso normal como
    -- el de nivel maximo / quest sin XP (xpReal = 0) sin estimaciones.
    hc:SetScript("OnUpdate", function(_, elapsed)
      if not (pendingXP and pendingXP.armed) then return end
      pendingXP.t = (pendingXP.t or 0) + (elapsed or 0)
      if pendingXP.t < 0.2 then return end
      local cd     = EnsureCD()
      local after  = (UnitXP and UnitXP("player")) or 0
      local xpReal = after - pendingXP.xpBefore
      if xpReal < 0 then
        -- Subio de nivel al entregar: cruzar el limite de nivel.
        xpReal = (pendingXP.maxBefore - pendingXP.xpBefore) + after
      end
      local r = cd.rewards[pendingXP.qid] or {}
      r.playerLevel = pendingXP.levelBefore
      r.xpReal      = xpReal
      if pendingXP.money then r.money = pendingXP.money end
      cd.rewards[pendingXP.qid] = r
      pendingXP = nil
    end)

    -- ── Exportacion: /skq export ────────────────────────────────────────────────
    function Collector:Export()
      local cd = EnsureCD()
      local function count(t) local n = 0; if t then for _ in pairs(t) do n = n + 1 end end return n end
      local es = SKquests_Localization and SKquests_Localization.currentLanguage == "esES"
      local nQ, nR, nN, nD = count(cd.quests), count(cd.rewards), count(cd.npcs), count(cd.deaths)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99=== SKquests :: Datos recolectados (SKQ_CollectedData) ===|r")
      DEFAULT_CHAT_FRAME:AddMessage(("|cffffff00Quests:|r %d   |cffffff00Rewards (XP real):|r %d   |cffffff00NPCs:|r %d   |cffffff00Deaths:|r %d"):format(nQ, nR, nN, nD))
      local customN = 0
      for _, q in pairs(cd.quests) do if q.isCustom then customN = customN + 1 end end
      DEFAULT_CHAT_FRAME:AddMessage(("|cffff9933Quests custom del servidor detectadas:|r %d"):format(customN))
      if es then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffLos datos se guardan en WTF/Account/<cuenta>/SavedVariables/SKquests.lua")
        DEFAULT_CHAT_FRAME:AddMessage("(variable SKQ_CollectedData) al hacer /reload o cerrar sesion.|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffData is written to WTF/Account/<acc>/SavedVariables/SKquests.lua")
        DEFAULT_CHAT_FRAME:AddMessage("(SKQ_CollectedData variable) on /reload or logout.|r")
      end
      return cd
    end
  end
