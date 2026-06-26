-- ==========================================
-- RECEPTOR (POCKET COMPUTER)
-- ==========================================

-- Procura o modem sem fio automaticamente no Pocket
local modem = peripheral.find("modem", function(name, object) return object.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    term.clear()
    term.setCursorPos(1,1)
    print("Erro: Modem sem fio nao encontrado!")
    print("Use um Advanced Wireless Pocket.")
    return
end

-- Formatação de sufixos (k, M, G, T)
local function formatNum(val)
    if val >= 10^12 then return string.format("%.2f T", val / 10^12)
    elseif val >= 10^9 then return string.format("%.2f G", val / 10^9)
    elseif val >= 10^6 then return string.format("%.2f M", val / 10^6)
    elseif val >= 10^3 then return string.format("%.1f k", val / 10^3)
    else return string.format("%.0f", val) end
end

while true do
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.yellow)
    print("=== MONITOR DE BOLSO ===")
    
    -- Fica escutando a rede sem fio
    local id, pacote = rednet.receive("dados_energia", 5)
    
    if pacote then
        -- ==========================================
        -- PARTE SUPERIOR: INDUCTION CASING
        -- ==========================================
        if pacote.bateria.encontrada then
            local pct = (pacote.bateria.atual / pacote.bateria.max) * 100
            term.setTextColor(colors.magenta)
            print("\n[ ARMAZENAMENTO ]")
            term.setTextColor(colors.white)
            print("Carga: " .. string.format("%.1f", pct) .. "%")
            print("Atual: " .. formatNum(pacote.bateria.atual) .. " FE")
            print("Max:   " .. formatNum(pacote.bateria.max) .. " FE")
        else
            term.setTextColor(colors.red)
            print("\n[ ARMAZENAMENTO ]")
            print("Induction Matrix offline.")
        end
        
        term.setTextColor(colors.gray)
        print("-----------------------")
        
        -- ==========================================
        -- PARTE INFERIOR: REATORES E TURBINAS
        -- ==========================================
        term.setTextColor(colors.cyan)
        print("[ MAQUINAS ATIVAS ]")
        term.setTextColor(colors.white)
        
        if #pacote.maquinas > 0 then
            for _, maq in ipairs(pacote.maquinas) do
                print("- " .. maq.nome)
                
                if maq.tipo == "BigReactors-Turbine" or maq.tipo == "turbineValve" then
                    print("  Prod: " .. formatNum(maq.geracao) .. " FE/t")
                    if maq.tipo == "BigReactors-Turbine" then
                        print("  RPM:  " .. string.format("%.0f", maq.extra))
                    end
                else
                    print("  Temp: " .. string.format("%.0f", maq.extra) .. " C/K")
                end
            end
        else
            term.setTextColor(colors.lightGray)
            print("Nenhuma maquina detectada.")
        end
    else
        term.setTextColor(colors.red)
        print("\nErro: Sem sinal da base!")
        print("Aguardando conexao...")
    end
    
    os.sleep(0.5)
end
