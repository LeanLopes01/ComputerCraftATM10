-- ==========================================
-- TRANSMISSOR DA BASE (COMPUTADOR FIXO)
-- ==========================================

-- Procura o modem sem fio automaticamente
local modem = peripheral.find("modem", function(name, object) return object.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("Erro: Modem sem fio nao encontrado na base!")
    return
end

-- Função para converter Joules (Mekanism) para FE
local function jToFE(joules) return joules * 0.4 end

-- Tipos de máquinas que vamos rastrear
local target_types = {
    ["BigReactors-Reactor"] = "Ext. Reactor",
    ["BigReactors-Turbine"] = "Ext. Turbine",
    ["fissionReactorLogicAdapter"] = "Mek Fission",
    ["turbineValve"] = "Mek Turbine"
}

while true do
    -- Estrutura do pacote de dados que será enviado
    local pacote = {
        bateria = { encontrada = false, atual = 0, max = 1 },
        maquinas = {}
    }
    
    -- Varre todos os cabos procurando as máquinas
    for _, name in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(name)
        
        -- Pega os dados do Armazenamento (Mekanism)
        if pType == "inductionMatrix" or pType == "inductionPort" then
            local matrix = peripheral.wrap(name)
            pacote.bateria.encontrada = true
            pacote.bateria.atual = jToFE(matrix.getEnergy and matrix.getEnergy() or 0)
            pacote.bateria.max = jToFE(matrix.getMaxEnergy and matrix.getMaxEnergy() or 1)
            
        -- Pega os dados dos Reatores e Turbinas
        elseif target_types[pType] then
            local device = peripheral.wrap(name)
            local info = {
                nome = target_types[pType] .. " (" .. string.sub(name, -3) .. ")",
                tipo = pType,
                geracao = 0,
                extra = 0
            }
            
            if pType == "BigReactors-Turbine" then
                info.geracao = device.getEnergyProducedLastTick and device.getEnergyProducedLastTick() or 0
                info.extra = device.getRotorSpeed and device.getRotorSpeed() or 0
            elseif pType == "turbineValve" then
                local power_j = device.getProductionRate and device.getProductionRate() or 0
                info.geracao = jToFE(power_j)
            elseif pType == "BigReactors-Reactor" or pType == "fissionReactorLogicAdapter" then
                info.extra = device.getTemperature and device.getTemperature() or 0
            end
            
            table.insert(pacote.maquinas, info)
        end
    end
    
    -- Envia o pacote completo para o Pocket Computer
    rednet.broadcast(pacote, "dados_energia")
    
    os.sleep(1) -- Atualiza a cada 1 segundo
end
