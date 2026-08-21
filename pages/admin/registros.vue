<template>
  <div>
    <div class="cabecalho">
      <div><h1>Registros</h1><p>Tudo o que aconteceu no sistema, com autor e horário.</p></div>
      <button class="btn btn-neutro btn-p" @click="carregar">Atualizar</button>
    </div>

    <div v-if="carregando" class="carregando">Carregando registros...</div>

    <div v-else class="painel">
      <div class="painel-topo">
        <h2>{{ filtrados.length }} registro(s)</h2>
        <input v-model="busca" class="campo" style="max-width:280px" type="search" placeholder="Buscar por pessoa ou ação" />
      </div>
      <TabelaVazia v-if="!filtrados.length" titulo="Nenhum registro" texto="As ações do sistema aparecem aqui." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Quando</th><th>Quem</th><th>O que aconteceu</th><th>Detalhes</th></tr></thead>
          <tbody>
            <tr v-for="r in filtrados" :key="r.id">
              <td>{{ dataHora(r.created_at) }}</td>
              <td><strong>{{ r.actor_name || '—' }}</strong></td>
              <td><span class="selo selo-neutro">{{ rotuloAcao(r.action) }}</span></td>
              <td class="mini">{{ resumo(r.details) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const registros = ref<any[]>([])
const carregando = ref(true)
const busca = ref('')

const rotuloAcao = (a: string) => ({
  pedido_criado: 'Pedido criado',
  pedido_puxado: 'Pedido puxado da fila',
  pedido_devolvido: 'Pedido devolvido a fila',
  pedido_redirecionado: 'Pedido redirecionado',
  pedido_enviado: 'Pedido enviado',
  pedido_recebido: 'Recebimento confirmado',
  pedido_retomado: 'Pedido retomado da espera',
  pedido_cancelado: 'Pedido cancelado',
  item_retirado: 'Item retirado do pedido',
  item_devolvido: 'Item devolvido ao pedido',
  venda_registrada: 'Venda registrada',
  usuario_aprovado: 'Usuário aprovado',
  usuario_status: 'Situação do usuário alterada',
  usuario_criado: 'Usuário criado',
  usuario_excluido: 'Usuário excluido',
  senha_redefinida: 'Senha redefinida',
  link_recuperacao: 'Link de recuperação gerado',
  senha_recuperada: 'Senha recuperada pelo próprio usuário'
}[a] ?? a)

const filtrados = computed(() => {
  const t = busca.value.trim().toLowerCase()
  if (!t) return registros.value
  return registros.value.filter(r => `${r.actor_name} ${rotuloAcao(r.action)}`.toLowerCase().includes(t))
})

function resumo(d: any) {
  if (!d || typeof d !== 'object') return '—'
  const partes = Object.entries(d)
    .filter(([, v]) => v !== null && typeof v !== 'object')
    .map(([k, v]) => `${k}: ${v}`)
  return partes.length ? partes.join(' · ') : '—'
}

async function carregar() {
  carregando.value = true
  const { data } = await supa.from('activity_log').select('*').order('created_at', { ascending: false }).limit(400)
  registros.value = data ?? []
  carregando.value = false
}
onMounted(carregar)
</script>
