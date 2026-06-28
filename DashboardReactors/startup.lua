-- ==========================================================
-- Monitoramento Universal & Piloto Automático de Fusão (ATM10)
-- ==========================================================

-- Configurações de Fissão e Exibição
local max_temp_extreme = 2000
local max_energy_bar = 5000000
local limite_dano_reator = 0.8   -- 80% (Mekanism retorna fracao 0-1, nao 0-100)
local limite_temp_fissao = 1150

-- Configurações da Fusão (Piloto Automático)
local limite_max_injection = 50
local min_reserva_combustivel = 10000

-- Nomes reais dos chemicals no AE2 (confirmados via getChemicals())
local NOME_TRITIUM = "mekanismgenerators:tritium"
local NOME_DEUTERIUM = "mekanismgenerators:deuterium"

-- Histórico e Variáveis de Estado
local energia_historico = {}
local ultimo_tritium = 0
local ultimo_deuterium = 0

-- Encontra o monitor
local monitor = peripheral.find("monitor")
if not monitor then
    print("Erro: Nenhum monitor conectado!")
    return
end

monitor.setTextScale(0.5)
local w, h = monitor.getSize()

-- Layout da Tela
local divisor_x = math.floor(w * 0.58)
local right_x = divisor_x + 3
local right_w = w - right_x - 1
local espaco_direito_h = h - 5
local graf_y = 4
local graf_h = math.floor(espaco_direito_h / 2) - 1
local max_pontos_grafico = right_w
local matriz_y = graf_y + graf_h + 3

-- Tipos de periféricos corretos para ATM10
local target_types = {
    ["BigReactors-Reactor"] = "Extreme Reactor",
    ["BigReactors-Turbine"] = "Extreme Turbine",
    ["fissionReactorLogicAdapter"] = "Mek Fission",
    ["turbineValve"] = "Mek Turbine",
    ["fusionReactorLogicAdapter"] = "Mek Fusion"
}

-- Conversão e Formatação
local function jToFE(joules) return joules * 0.4 end

local function formatNum(val)
    val = val or 0
    if val >= 10^12 then return string.format("%.2f T", val / 10^12)
    elseif val >= 10^9 then return string.format("%.2f G", val / 10^9)
    elseif val >= 10^6 then return string.format("%.2f M", val / 10^6)
    elseif val >= 10^3 then return string.format("%.1f k", val / 10^3)
    else return string.format("%.2f", val) end
end

-- ==========================================================
-- Leitura de "Chemicals" do AE2 (API getChemical / campo count)
-- ==========================================================
local function getAE2Fuel(me_bridge, nome_gas)
    if not me_bridge then return 0 end

    if me_bridge.getChemical then
        local chem = me_bridge.getChemical({ name = nome_gas })
        if chem and chem.count then return chem.count end
    end

    -- Fallback de segurança para Fluidos
    if me_bridge.getFluid then
        local fluid = me_bridge.getFluid({ name = nome_gas })
        if fluid and fluid.count then return fluid.count end
        if fluid and fluid.amount then return fluid.amount end
    end

    return 0
end

-- Desenho de Barra
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

-- Gráfico de LINHA (energia x tempo), em vez do gráfico de colunas anterior
local function drawLineGraph(mon, x, y, width, height, data)
    mon.setCursorPos(x, y - 2)
    mon.setTextColor(colors.cyan)
    mon.write("HISTORICO DE GERACAO TOTAL")

    local max_no_grafico = 1000
    for i = 1, #data do if data[i] > max_no_grafico then max_no_grafico = data[i] end end

    mon.setCursorPos(x, y - 1)
    mon.setTextColor(colors.lightGray)
    mon.write("Pico: " .. formatNum(max_no_grafico) .. " FE/t")

    -- Fundo da área do gráfico
    mon.setBackgroundColor(colors.gray)
    for i = 0, height - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", width))
    end

    local function linhaParaValor(val)
        local pct = math.min(1, math.max(0, val / max_no_grafico))
        local altura = math.floor((height - 1) * pct)
        return y + height - 1 - altura
    end

    mon.setBackgroundColor(colors.lime)
    local idx_dados = #data
    local linha_anterior = nil
    for col = width, 1, -1 do
        if idx_dados < 1 then break end
        local px = x + col - 1
        local linha_atual = linhaParaValor(data[idx_dados])

        local de, ate = linha_atual, (linha_anterior or linha_atual)
        if de > ate then de, ate = ate, de end
        for ly = de, ate do
            mon.setCursorPos(px, ly)
            mon.write(" ")
        end

        linha_anterior = linha_atual
        idx_dados = idx_dados - 1
    end

    mon.setBackgroundColor(colors.black)
end

-- Loop Principal
while true do
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 1)
    monitor.setTextColor(colors.yellow)
    monitor.write("================= PAINEL CENTRAL DE ENERGIA =================")

    local y_offset = 3
    local geracao_total_tick = 0
    local matrix_found = false
    local matrix_energy_j, matrix_max_j = 0, 1

    -- Desenha a linha divisória vertical
    for line = 3, h - 1 do
        monitor.setCursorPos(divisor_x, line)
        monitor.setTextColor(colors.gray)
        monitor.write("|")
    end

    -- ==========================================================
    -- LEITURA DO AE2 (TRITIUM E DEUTERIUM)
    -- ==========================================================
    local me = peripheral.wrap("me_bridge_1")
    local current_t = getAE2Fuel(me, NOME_TRITIUM)
    local current_d = getAE2Fuel(me, NOME_DEUTERIUM)

    local taxa_t = (current_t - ultimo_tritium) / 10
    local taxa_d = (current_d - ultimo_deuterium) / 10

    ultimo_tritium = current_t
    ultimo_deuterium = current_d

    -- Processamento dos Periféricos
    for _, name in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(name)

        if pType == "inductionMatrix" or pType == "inductionPort" then
            local device = peripheral.wrap(name)
            matrix_energy_j = device.getEnergy and device.getEnergy() or 0
            matrix_max_j = device.getMaxEnergy and device.getMaxEnergy() or 1
            matrix_found = true

        elseif target_types[pType] then
            local device = peripheral.wrap(name)
            local devName = target_types[pType] .. " (" .. string.sub(name, -3) .. ")"

            if pType == "BigReactors-Reactor" then
                local temp = device.getTemperature and device.getTemperature() or 0
                local energy = device.getEnergyStored and device.getEnergyStored() or 0
                local fuelAmt = device.getFuelAmount and device.getFuelAmount() or 0
                local fuelMax = device.getFuelAmountMax and device.getFuelAmountMax() or 1
                local ativo = device.getActive and device.getActive() or false

                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Temp", temp, max_temp_extreme, colors.red, "C")
                monitor.setCursorPos(2, y_offset + 2)
                monitor.setTextColor(colors.lightGray)
                monitor.write(string.format("Energia: %s FE | Comb: %.0f%% | Ativo: %s",
                    formatNum(energy), (fuelAmt / fuelMax) * 100, ativo and "SIM" or "NAO"))
                y_offset = y_offset + 4

            elseif pType == "BigReactors-Turbine" then
                local power = device.getEnergyProducedLastTick and device.getEnergyProducedLastTick() or 0
                geracao_total_tick = geracao_total_tick + power
                local rpm = device.getRotorSpeed and device.getRotorSpeed() or 0
                local flow = device.getFluidFlowRate and device.getFluidFlowRate() or 0
                local flowMax = device.getFluidFlowRateMax and device.getFluidFlowRateMax() or 1

                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Prod", power, max_energy_bar, colors.green, "FE/t")
                monitor.setCursorPos(2, y_offset + 2)
                monitor.setTextColor(colors.lightGray)
                monitor.write(string.format("RPM: %.0f | Flow: %s/%s mB/t", rpm, formatNum(flow), formatNum(flowMax)))
                y_offset = y_offset + 4

            elseif pType == "turbineValve" then
                local power_j = device.getProductionRate and device.getProductionRate() or 0
                local power_fe = jToFE(power_j)
                geracao_total_tick = geracao_total_tick + power_fe
                local flow = device.getFlowRate and device.getFlowRate() or 0
                local flowMax = device.getMaxFlowRate and device.getMaxFlowRate() or 1
                local steamPct = device.getSteamFilledPercentage and device.getSteamFilledPercentage() or 0

                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Prod", power_fe, max_energy_bar, colors.green, "FE/t")
                monitor.setCursorPos(2, y_offset + 2)
                monitor.setTextColor(colors.lightGray)
                monitor.write(string.format("Flow: %s/%s mB/t | Vapor: %.0f%%",
                    formatNum(flow), formatNum(flowMax), steamPct * 100))
                y_offset = y_offset + 4

            elseif pType == "fissionReactorLogicAdapter" then
                local temp = device.getTemperature and device.getTemperature() or 0
                local damage = device.getDamagePercent and device.getDamagePercent() or 0
                local burn = device.getActualBurnRate and device.getActualBurnRate() or (device.getBurnRate and device.getBurnRate() or 0)
                local burnMax = device.getMaxBurnRate and device.getMaxBurnRate() or 1
                local fuelPct = device.getFuelFilledPercentage and device.getFuelFilledPercentage() or 0
                local coolantPct = device.getCoolantFilledPercentage and device.getCoolantFilledPercentage() or 0

                -- Segurança SCRAM (Dano ou Temperatura crítica)
                if damage > limite_dano_reator or temp > limite_temp_fissao then
                    if device.scram then device.scram() end
                    monitor.setCursorPos(2, y_offset)
                    monitor.setTextColor(colors.red)
                    monitor.write("CRITICO: Reator desativado por Dano/Temp!")
                    y_offset = y_offset + 1
                end

                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Temp", temp, 1200, colors.orange, "K")
                monitor.setCursorPos(2, y_offset + 2)
                monitor.setTextColor(colors.lightGray)
                monitor.write(string.format("Burn: %.1f/%.0f mB/t | Dano: %.1f%% | Comb: %.0f%% | Refrig: %.0f%%",
                    burn, burnMax, damage * 100, fuelPct * 100, coolantPct * 100))
                y_offset = y_offset + 4

            elseif pType == "fusionReactorLogicAdapter" then
                -- Piloto Automático de Fusão
                local inj_rate = device.getInjectionRate and device.getInjectionRate() or 2
                local power_j = device.getProductionRate and device.getProductionRate() or 0
                local power_fe = jToFE(power_j)
                local plasma_temp = device.getPlasmaTemperature and device.getPlasmaTemperature() or 0
                local case_temp = device.getCaseTemperature and device.getCaseTemperature() or 0
                local tritio_pct = device.getTritiumFilledPercentage and device.getTritiumFilledPercentage() or 0
                local deut_pct = device.getDeuteriumFilledPercentage and device.getDeuteriumFilledPercentage() or 0

                geracao_total_tick = geracao_total_tick + power_fe

                if current_t < min_reserva_combustivel or current_d < min_reserva_combustivel then
                    if inj_rate > 2 then device.setInjectionRate(2) end
                elseif taxa_t < 0 or taxa_d < 0 then
                    if inj_rate > 2 then device.setInjectionRate(inj_rate - 2) end
                elseif taxa_t > 0 and taxa_d > 0 and current_t > min_reserva_combustivel and current_d > min_reserva_combustivel then
                    if inj_rate < limite_max_injection then device.setInjectionRate(inj_rate + 2) end
                end

                drawBar(monitor, 2, y_offset, divisor_x - 4, devName .. " - Prod", power_fe, max_energy_bar, colors.yellow, "FE/t")
                monitor.setCursorPos(2, y_offset + 2)
                monitor.setTextColor(colors.lightBlue)
                monitor.write(string.format("Injecao: %d mb/t | Plasma: %s K | Case: %s K",
                    inj_rate, formatNum(plasma_temp), formatNum(case_temp)))
                monitor.setCursorPos(2, y_offset + 3)
                monitor.setTextColor(colors.lightGray)
                monitor.write(string.format("Tritio: %.0f%% | Deuterio: %.0f%%", tritio_pct * 100, deut_pct * 100))
                y_offset = y_offset + 5
            end
        end

        if y_offset > h - 3 then break end
    end

    -- ==========================================================
    -- RENDERIZAÇÃO DO LADO DIREITO (40% DA TELA)
    -- ==========================================================
    table.insert(energia_historico, geracao_total_tick)
    if #energia_historico > max_pontos_grafico then table.remove(energia_historico, 1) end
    drawLineGraph(monitor, right_x, graf_y, right_w, graf_h, energia_historico)

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

        drawBar(monitor, right_x, matriz_y + 6, right_w, "Capacidade", fe_atual, fe_max, colors.purple, "FE")
    else
        monitor.setCursorPos(right_x, matriz_y + 2)
        monitor.setTextColor(colors.red)
        monitor.write("Induction Matrix nao dectada.")
    end

    -- Status de Geração Geral no rodapé esquerdo
    monitor.setCursorPos(2, h - 1)
    monitor.setTextColor(colors.lime)
    monitor.write("GERACAO TOTAL DA BASE: " .. formatNum(geracao_total_tick) .. " FE/t")

    if me then
        monitor.setCursorPos(right_x, h - 3)
        monitor.setTextColor(colors.orange)
        monitor.write("Tritium:   " .. formatNum(current_t) .. " (" .. (taxa_t >= 0 and "+" or "") .. formatNum(taxa_t) .. "/t)")
        monitor.setCursorPos(right_x, h - 2)
        monitor.setTextColor(colors.cyan)
        monitor.write("Deuterium: " .. formatNum(current_d) .. " (" .. (taxa_d >= 0 and "+" or "") .. formatNum(taxa_d) .. "/t)")
    end

    os.sleep(10)
end
