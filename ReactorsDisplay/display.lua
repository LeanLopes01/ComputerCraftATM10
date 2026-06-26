-- ==========================================================
-- Sistema de Monitoramento Universal & Gráfico Histórico (ATM10)
-- ==========================================================

-- Configurações de limites para os gráficos de barra
local max_temp_extreme = 2000 
local max_speed_extreme = 2000 
local max_energy_bar = 500000 

-- Histórico do Gráfico de Tempo
local energia_historico = {}

-- Encontra o monitor
local monitor = peripheral.find("monitor")
if not monitor then
    print("Erro: Nenhum monitor conectado!")
    return
end

monitor.setTextScale(0.5)
local w, h = monitor.getSize()

-- Definição do layout baseado no tamanho do display 8x5
local divisor_x = math.floor(w * 0.58)
local right_x = divisor_x + 3
local right_w = w - right_x - 1

-- Dividindo os 40% da direita em duas metades (Cima: Gráfico / Baixo: Bateria)
local espaco_direito_h = h - 5
local graf_y = 4
local graf_h = math.floor(espaco_direito_h / 2) - 1
local max_pontos_grafico = right_w

local matriz_y = graf_y + graf_h + 3 -- Onde começa a parte da bateria

-- Tipos de periféricos na rede para o lado esquerdo
local target_types = {
    ["BigReactors-Reactor"] = "Extreme Reactor",
    ["BigReactors-Turbine"] = "Extreme Turbine",
    ["fissionReactorLogicAdapter"] = "Mek Fission",
    ["turbineValve"] = "Mek Turbine"
}

-- Conversão de unidade (1 Joule = 0.4 FE)
local function jToFE(joules)
    return joules * 0.4
end

-- Formatação de sufixos de engenharia
local function formatNum(val)
    if val >= 10^12 then return string.format("%.2f T", val / 10^12)
    elseif val >= 10^9 then return string.format("%.2f G", val / 10^9)
    elseif val >= 10^6 then return string.format("%.2f M", val / 10^6)
    elseif val >= 10^3 then return string.format("%.1f k", val / 10^3)
    else return string.format("%.2f", val) end
end

-- Desenha barras de progresso horizontais
local function drawBar(mon, x, y, width, label, value, max_val, color, unit)
    mon.setCursorPos(x, y)
    mon.setTextColor(colors.white)
    mon.write(label .. ": " .. formatNum(value) .. " " .. unit)

    local percent = math.min(1, math.max(0, value / max_val))
    local barWidth = math.floor(width * percent)

    mon.setCursorPos(x, y + 1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", width)) 
    
    mon.setCursorPos(x, y + 1)
    mon.setBackgroundColor(color)
    mon.write(string.rep(" ", barWidth)) 
    
    mon.setBackgroundColor(colors.black)
end

-- Desenha o Gráfico Temporal (Energia x Tempo)
local function drawTrendGraph(mon, x, y, width, height, data)
    mon.setCursorPos(x, y - 2)
    mon.setTextColor(colors.cyan)
    mon.write("HISTORICO DE GERACAO TOTAL")
    
    local max_no_grafico = 1000 
    for i = 1, #data do
        if data[i] > max_no_grafico then max_no_grafico = data[i] end
    end
    
    mon.setCursorPos(x, y - 1)
    mon.setTextColor(colors.lightGray)
    mon.write("Pico: " .. formatNum(max_no_grafico) .. " FE/t")

    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.setBackgroundColor(colors.blue) 
        mon.write(string.rep(" ", width))
    end

    mon.setBackgroundColor(colors.lime) 
    local idx_dados = #data
    for col = width, 1, -1 do
        if idx_dados < 1 then break end
        
        local val = data[idx_dados]
        local pct = val / max_no_grafico
        local altura_barra = math.floor(height * pct)
        
        for linha = 0, altura_barra - 1 do
            mon.setCursorPos(x + col - 1, y + height - 1 - linha)
            mon.write(" ")
        end
        idx_dados = idx_dados - 1
    end
    mon.setBackgroundColor(colors.black)
end

-- Loop Principal
while true do
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    -- Cabeçalho Principal
    monitor.setCursorPos(2, 1)
    monitor.setTextColor(colors.yellow)
    monitor.write("================= PAINEL CENTRAL DE ENERGIA =================")

    local y_offset = 3
    local geracao_total_tick = 0

    -- Variáveis para guardar o estado da Matriz do Mekanism
    local matrix_found = false
    local matrix_energy_j = 0
    local matrix_max_j = 1

    -- Divisor vertical
    for line = 3, h - 1 do
        monitor.setCursorPos(divisor_x, line)
        monitor.setTextColor(colors.gray)
        monitor.write("|")
    end

    -- Processamento de Periféricos
    for _, name in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(name)
        
        -- Aceita tanto inductionMatrix quanto inductionPort para a bateria do Mekanism
        if pType == "inductionMatrix" or pType == "inductionPort" then
            local device = peripheral.wrap(name)
            matrix_energy_j = device.getEnergy and device.getEnergy() or 0
            matrix_max_j = device.getMaxEnergy and device.getMaxEnergy() or 1
            matrix_found = true
        
        -- Processa Reatores e Turbinas na esquerda
        elseif target_types[pType] then
            local device = peripheral.wrap(name)
            local devName = target_types[pType] .. " (" .. string.sub(name, -3) .. ")"
            
            if pType == "BigReactors-Reactor" then
                local temp = device.getTemperature and device.getTemperature() or 0
                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Temp", temp, max_temp_extreme, colors.red, "C")
                y_offset = y_offset + 3
                
            elseif pType == "BigReactors-Turbine" then
                local speed = device.getRotorSpeed and device.getRotorSpeed() or 0
                local power = device.getEnergyProducedLastTick and device.getEnergyProducedLastTick() or 0
                geracao_total_tick = geracao_total_tick + power
                
                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Prod", power, max_energy_bar, colors.green, "FE/t")
                y_offset = y_offset + 3

            elseif pType == "fissionReactorLogicAdapter" then
                local temp = device.getTemperature and device.getTemperature() or 0
                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Temp", temp, 1200, colors.orange, "K")
                y_offset = y_offset + 3

            elseif pType == "turbineValve" then
                local power_j = device.getProductionRate and device.getProductionRate() or 0
                local power_fe = jToFE(power_j)
                geracao_total_tick = geracao_total_tick + power_fe
                
                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Prod", power_fe, max_energy_bar, colors.green, "FE/t")
                y_offset = y_offset + 3
            end
        end
        
        if y_offset > h - 3 then break end
    end

    -- ==========================================================
    -- RENDERIZAÇÃO DO LADO DIREITO (40% DA TELA)
    -- ==========================================================

    -- 1. Atualiza e desenha o Gráfico Temporal (Metade de Cima)
    table.insert(energia_historico, geracao_total_tick)
    if #energia_historico > max_pontos_grafico then
        table.remove(energia_historico, 1)
    end
    drawTrendGraph(monitor, right_x, graf_y, right_w, graf_h, energia_historico)

    -- 2. Desenha o Status do Armazenamento (Metade de Baixo)
    monitor.setCursorPos(right_x, matriz_y)
    monitor.setTextColor(colors.magenta)
    monitor.write("STATUS DO ARMAZENAMENTO (MATRIX)")

    if matrix_found then
        local fe_atual = jToFE(matrix_energy_j)
        local fe_max = jToFE(matrix_max_j)
        local fe_falta = fe_max - fe_atual
        local pct = (fe_atual / fe_max) * 100

        monitor.setCursorPos(right_x, matriz_y + 2)
        monitor.setTextColor(colors.white)
        monitor.write("Carga Atual: " .. string.format("%.1f", pct) .. "%")
        
        monitor.setCursorPos(right_x, matriz_y + 3)
        monitor.setTextColor(colors.lightBlue)
        monitor.write("Armazenado: " .. formatNum(fe_atual) .. " FE")
        
        monitor.setCursorPos(right_x, matriz_y + 4)
        monitor.setTextColor(colors.red)
        monitor.write("Falta:      " .. formatNum(fe_falta) .. " FE")
        
        -- Barra gráfica de capacidade da bateria
        drawBar(monitor, right_x, matriz_y + 6, right_w, "Capacidade", fe_atual, fe_max, colors.purple, "FE")
    else
        monitor.setCursorPos(right_x, matriz_y + 2)
        monitor.setTextColor(colors.red)
        monitor.write("Induction Matrix nao dectada.")
        monitor.setCursorPos(right_x, matriz_y + 3)
        monitor.setTextColor(colors.lightGray)
        monitor.write("Verifique a conexao do modem")
        monitor.setCursorPos(right_x, matriz_y + 4)
        monitor.write("no Induction Port.")
    end

    -- Status de Geração Geral no rodapé esquerdo
    monitor.setCursorPos(2, h - 1)
    monitor.setTextColor(colors.lime)
    monitor.write("GERACAO TOTAL DA BASE: " .. formatNum(geracao_total_tick) .. " FE/t")

    os.sleep(1.5)
end
