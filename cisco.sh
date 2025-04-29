#verificar informação da interface
expect {
    -re "(.*)#" {
        set output $expect_out(1,string)
if {[regexp {is up, line protocol is up} $output]} {
    puts "✅ Interface ativa: is up, line protocol is up"
} elseif {[regexp {is up, line protocol is down} $output]} {
    puts "⚠️ Interface ligada fisicamente, mas sem conectividade: is up, line protocol is down."
} elseif {[regexp {is down, line protocol is down} $output]} {
    puts "❌ Interface desligada ou sem cabo: is down, line protocol is down."
} elseif {[regexp {administratively down} $output]} {
    puts "🔒 Interface desabilitada manualmente (shutdown): administratively down"
} else {
            puts "ℹ️ Estado da interface não identificado"
        }
        }
}