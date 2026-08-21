<template>
  <div class="sino-area">
    <button class="sino" :aria-label="`${avisos.length} avisos`" @click="painel = !painel">
      <span>&#128276;</span>
      <span v-if="avisos.length" class="sino-conta">{{ avisos.length }}</span>
    </button>

    <div v-if="painel" class="sino-painel">
      <div class="sino-topo">
        <strong>Avisos</strong>
        <button v-if="avisos.length" class="btn-linha" @click="lerTodos">Marcar todos como lidos</button>
      </div>
      <div v-if="!avisos.length" class="mini centro" style="padding:26px">Nenhum aviso novo.</div>
      <button v-for="a in avisos" :key="a.id" class="sino-item" @click="abrir(a)">
        <span class="selo" :class="corAviso(a.kind)">{{ rotuloAviso(a.kind) }}</span>
        <strong>{{ a.title }}</strong>
        <span class="mini">{{ a.body }}</span>
        <span class="mini">{{ dataHora(a.created_at) }}</span>
      </button>
    </div>

    <div v-if="popup && avisos.length" class="fundo-janela" @click.self="fecharPopup">
      <div class="janela" style="max-width:460px">
        <div class="janela-topo">
          <h3>Você tem {{ avisos.length }} aviso(s)</h3>
          <button class="fechar" aria-label="Fechar" @click="fecharPopup">&times;</button>
        </div>
        <div class="janela-corpo">
          <button v-for="a in avisos.slice(0, 6)" :key="a.id" class="sino-item" @click="abrir(a)">
            <span class="selo" :class="corAviso(a.kind)">{{ rotuloAviso(a.kind) }}</span>
            <strong>{{ a.title }}</strong>
            <span class="mini">{{ a.body }}</span>
          </button>
          <p v-if="avisos.length > 6" class="mini centro" style="margin-top:12px">
            e mais {{ avisos.length - 6 }} aviso(s) no sino do topo.
          </p>
        </div>
        <div class="janela-base">
          <button class="btn btn-neutro btn-p" @click="lerTodos">Marcar todos como lidos</button>
          <button class="btn btn-principal btn-p" style="width:auto" @click="fecharPopup">Entendi</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const supa = useSupa()
const rota = useRoute()
const avisos = useState<any[]>('avisos', () => [])
const painel = ref(false)
const popup = ref(false)
const jaMostrou = useState('avisos-popup', () => false)

const rotuloAviso = (k: string) => ({
  pedido: 'Pedido', mensagem: 'Mensagem', recebimento: 'Recebimento',
  cadastro: 'Cadastro', acesso: 'Acesso'
}[k] ?? 'Aviso')

const corAviso = (k: string) => ({
  mensagem: 'selo-atendimento', recebimento: 'selo-fila',
  cadastro: 'selo-laranja', acesso: 'selo-enviado'
}[k] ?? 'selo-neutro')

async function carregar() {
  const { data } = await supa.rpc('fn_my_notifications')
  avisos.value = data ?? []
  if (!jaMostrou.value && avisos.value.length) { popup.value = true; jaMostrou.value = true }
}

onMounted(() => {
  carregar()
  const t = setInterval(carregar, 60000)
  onUnmounted(() => clearInterval(t))
})
watch(() => rota.path, carregar)

async function lerTodos() {
  const ids = avisos.value.map(a => a.id)
  if (!ids.length) return
  await supa.rpc('fn_read_notifications', { p_ids: ids })
  avisos.value = []
  popup.value = false; painel.value = false
}

async function abrir(a: any) {
  await supa.rpc('fn_read_notifications', { p_ids: [a.id] })
  avisos.value = avisos.value.filter(x => x.id !== a.id)
  popup.value = false; painel.value = false

  const papel = useSessao().value.perfil?.role
  if (a.kind === 'cadastro') return navigateTo('/admin/usuarios')
  if (!a.order_id) return

  // leva direto ao pedido, ja com a janela aberta
  const destino = papel === 'admin' ? '/admin/pedidos'
    : papel === 'atendente' ? '/atendimentos'
    : '/pedidos'
  return navigateTo({ path: destino, query: { pedido: a.order_id, t: Date.now() } })
}

function fecharPopup() { popup.value = false }
</script>

<style scoped>
.sino-area { position: relative; }
.sino {
  position: relative; background: var(--campo); border: 1px solid var(--linha);
  border-radius: 999px; width: 40px; height: 40px; font-size: 17px; cursor: pointer;
}
.sino:hover { background: #f3ebe7; }
.sino-conta {
  position: absolute; top: -4px; right: -4px; background: var(--laranja); color: #fff;
  border-radius: 999px; min-width: 19px; height: 19px; font-size: 11px; font-weight: 700;
  display: grid; place-items: center; padding: 0 5px;
}
.sino-painel {
  position: absolute; right: 0; top: 48px; width: 330px; max-height: 420px; overflow-y: auto;
  background: #fff; border: 1px solid var(--linha); border-radius: 14px;
  box-shadow: var(--sombra); z-index: 60;
}
.sino-topo { padding: 13px 16px; border-bottom: 1px solid var(--linha); display: flex; justify-content: space-between; align-items: center; }
.sino-item {
  display: flex; flex-direction: column; gap: 4px; align-items: flex-start;
  width: 100%; text-align: left; padding: 13px 16px; background: none;
  border: 0; border-bottom: 1px solid var(--linha); cursor: pointer; font: inherit;
}
.sino-item:hover { background: #fdf7f5; }
.sino-item strong { font-size: 13.5px; color: var(--tinta); }
.janela-corpo .sino-item { border: 1px solid var(--linha); border-radius: 12px; margin-bottom: 10px; }
</style>
