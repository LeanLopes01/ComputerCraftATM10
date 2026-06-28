local ponte = peripheral.wrap("me_bridge_1")

if not ponte then
    print("ERRO: me_bridge_1 nao encontrado.")
    return
end

local metodos = peripheral.getMethods("me_bridge_1")
local arquivo = fs.open("metodos_ae2.txt", "w")

print("=== METODOS DISPONIVEIS ===")
for _, nome in ipairs(metodos) do
    arquivo.writeLine(nome)
    print("- " .. nome)
end

arquivo.close()
print("\nConcluido! Salvo em 'metodos_ae2.txt'")