local saida = fs.open("teste_fusao_output.txt", "w")
local function log(texto)
    print(texto)
    saida.writeLine(texto)
end

log("=== DIAGNOSTICO REATOR DE FUSAO ===")

-- 1. Lista todos os periféricos conectados e seus tipos
log("")
log("[ PERIFERICOS CONECTADOS ]")
local nomes = peripheral.getNames()
for _, name in ipairs(nomes) do
    local pType = peripheral.getType(name)
    log(name .. " -> " .. tostring(pType))
end

-- 2. Acha o periférico de fusão (tenta varios tipos possiveis)
local nome_fusao = nil
local tipo_fusao = nil
for _, name in ipairs(nomes) do
    local pType = peripheral.getType(name)
    if pType and string.find(string.lower(pType), "fusion") then
        nome_fusao = name
        tipo_fusao = pType
        break
    end
end

if not nome_fusao then
    log("")
    log("ERRO: Nenhum periferico com 'fusion' no tipo foi encontrado.")
    log("Verifique se o Logic Adapter esta encostado no reator e se ha um Wired Modem.")
    saida.close()
    return
end

log("")
log("Periferico de fusao encontrado: " .. nome_fusao .. " (tipo: " .. tipo_fusao .. ")")

local device = peripheral.wrap(nome_fusao)

-- 3. Lista TODOS os metodos disponiveis nesse periferico
log("")
log("[ METODOS DISPONIVEIS ]")
local metodos = peripheral.getMethods(nome_fusao)
for _, m in ipairs(metodos) do
    log("- " .. m)
end

-- 4. Testa cada metodo relevante manualmente com pcall
log("")
log("[ TESTANDO VALORES ]")
local metodos_teste = {
    "getProduction",
    "getProductionRate",
    "getInjectionRate",
    "getMinInjectionRate",
    "getMaxInjectionRate",
    "getPlasmaTemperature",
    "getCaseTemperature",
    "getTritium",
    "getTritiumCapacity",
    "getTritiumFilledPercentage",
    "getDeuterium",
    "getDeuteriumCapacity",
    "getDeuteriumFilledPercentage",
    "getDTFuel",
    "getDTFuelFilledPercentage",
    "getHohlraum",
    "getStatus",
    "isFormed",
    "isFormedReactor",
    "getEnergy",
    "getEnergyCapacity",
}

for _, nome_metodo in ipairs(metodos_teste) do
    if device[nome_metodo] then
        local ok, resultado = pcall(device[nome_metodo])
        if ok then
            if type(resultado) == "table" then
                log(nome_metodo .. "() -> " .. textutils.serialize(resultado))
            else
                log(nome_metodo .. "() -> " .. tostring(resultado))
            end
        else
            log(nome_metodo .. "() -> ERRO: " .. tostring(resultado))
        end
    else
        log(nome_metodo .. "() -> metodo nao existe nesse periferico")
    end
end

log("")
log("--- Fim do Teste ---")
log("Resultado salvo em 'teste_fusao_output.txt'")

saida.close()
