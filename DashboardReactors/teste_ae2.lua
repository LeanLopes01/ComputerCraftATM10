local me = peripheral.wrap("me_bridge_1")

local saida = fs.open("teste_ae2_output.txt", "w")
local function log(texto)
    print(texto)
    saida.writeLine(texto)
end

if not me then
    log("ERRO CRITICO: Nao encontrei o me_bridge_1.")
    log("Verifique se o cabo (Wired Modem) esta ligado")
    log("na ponte e ativado (clique com o botao direito).")
    saida.close()
    return
end

log("=== DIAGNOSTICO ME BRIDGE ===")

-- 1. Lista TODOS os chemicals do sistema via getChemicals()
log("")
log("[ TESTANDO getChemicals() ]")
if me.getChemicals then
    local chems = me.getChemicals()
    if type(chems) == "table" and #chems > 0 then
        log("Total de chemicals encontrados: " .. #chems)
        for _, c in ipairs(chems) do
            -- Mostra a estrutura crua pra confirmar os nomes dos campos (name/id, amount/count)
            log(textutils.serialize(c))
        end
    else
        log("getChemicals() retornou vazio ou nao e tabela.")
        log("Tipo retornado: " .. type(chems))
    end
else
    log("O comando getChemicals nao existe.")
end

-- 2. Procura tritium/deuterium especificamente dentro da lista
log("")
log("[ PROCURANDO TRITIUM/DEUTERIUM NA LISTA ]")
if me.getChemicals then
    local chems = me.getChemicals()
    local achei = false
    if type(chems) == "table" then
        for _, c in ipairs(chems) do
            local nome = c.name or c.id or ""
            if string.find(string.lower(nome), "tritium") or string.find(string.lower(nome), "deuterium") then
                log("ACHEI: " .. textutils.serialize(c))
                achei = true
            end
        end
    end
    if not achei then log("Nenhum tritium/deuterium na lista geral.") end
end

-- 3. Testa getChemical() direto, com variacoes de nome
log("")
log("[ TESTANDO getChemical() COM NOMES ESPECIFICOS ]")
local nomes_teste = {
    "mekanism:tritium",
    "mekanism:deuterium",
    "tritium",
    "deuterium",
}

for _, nome in ipairs(nomes_teste) do
    if me.getChemical then
        local ok, resultado = pcall(function() return me.getChemical({ name = nome }) end)
        if ok then
            if resultado then
                log("'" .. nome .. "' -> " .. textutils.serialize(resultado))
            else
                log("'" .. nome .. "' -> nil (nao encontrado)")
            end
        else
            log("'" .. nome .. "' -> ERRO: " .. tostring(resultado))
        end
    end
end

-- 4. Fallback: testa via getFluids/getFluid (caso o jogo trate como fluido)
log("")
log("[ TESTANDO getFluids() / getFluid() COMO FALLBACK ]")
if me.getFluids then
    local fluids = me.getFluids()
    if type(fluids) == "table" and #fluids > 0 then
        local achei = false
        for _, f in ipairs(fluids) do
            local nome = f.name or f.id or ""
            if string.find(string.lower(nome), "tritium") or string.find(string.lower(nome), "deuterium") then
                log("FLUIDO ACHADO: " .. textutils.serialize(f))
                achei = true
            end
        end
        if not achei then log("Nenhum tritium/deuterium em getFluids().") end
    else
        log("getFluids() vazio.")
    end
else
    log("O comando getFluids nao existe.")
end

log("")
log("--- Fim do Teste ---")
log("Resultado salvo em 'teste_ae2_output.txt'")

saida.close()
