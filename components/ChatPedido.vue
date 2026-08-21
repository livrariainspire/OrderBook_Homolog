<template>
  <div>
    <div ref="caixa" class="chat-caixa">
      <p v-if="!mensagens.length" class="mini centro" style="padding:20px">
        Ainda não ha mensagens. Escreva a primeira.
      </p>
      <template v-else>
        <div v-for="m in mensagens" :key="m.id"
             :class="['chat-msg', m.is_system ? 'chat-sistema' : (m.author_id === meuId ? 'chat-minha' : 'chat-outra')]">
          <div v-if="!m.is_system" class="chat-autor">
            {{ m.author_name }} · {{ rotuloPerfil(m.author_role) }}
          </div>
          <div class="chat-texto">{{ m.body }}</div>
          <div class="chat-hora">{{ dataHora(m.created_at) }}</div>
        </div>
      </template>
    </div>

    <div v-if="podeEscrever" class="chat-envio">
      <input v-model="texto" class="campo" placeholder="Escreva uma mensagem"
             @keyup.enter="enviar" />
      <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado || !texto.trim()" @click="enviar">
        Enviar
      </button>
    </div>
    <p v-else class="mini centro" style="margin-top:10px">Este pedido está encerrado. A conversa fica só no histórico.</p>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ pedidoId: string; encerrado?: boolean }>()
const emit = defineEmits(['enviou'])

const supa = useSupa()
const sessao = useSessao()
const meuId = computed(() => sessao.value.perfil?.id)
const podeEscrever = computed(() => !props.encerrado)

const mensagens = ref<any[]>([])
const texto = ref('')
const ocupado = ref(false)
const caixa = ref<HTMLElement | null>(null)

async function carregar() {
  const { data } = await supa.from('order_messages').select('*')
    .eq('order_id', props.pedidoId).order('created_at')
  mensagens.value = data ?? []
  await nextTick()
  if (caixa.value) caixa.value.scrollTop = caixa.value.scrollHeight
}
onMounted(carregar)
watch(() => props.pedidoId, carregar)

async function enviar() {
  if (!texto.value.trim()) return
  ocupado.value = true
  const { error } = await supa.rpc('fn_send_message', { p_order: props.pedidoId, p_body: texto.value })
  ocupado.value = false
  if (error) { alert(error.message); return }
  texto.value = ''
  await carregar()
  emit('enviou')
}
</script>

<style scoped>
.chat-caixa {
  max-height: 320px; overflow-y: auto; background: var(--campo);
  border: 1px solid var(--linha); border-radius: var(--raio-p); padding: 14px;
}
.chat-msg { margin-bottom: 12px; max-width: 86%; }
.chat-msg:last-child { margin-bottom: 0; }
.chat-autor { font-size: 11px; font-weight: 600; color: var(--rotulo); margin-bottom: 3px; }
.chat-texto {
  background: #fff; border: 1px solid var(--linha); border-radius: 12px;
  padding: 9px 13px; font-size: 13.5px; line-height: 1.5; color: var(--tinta);
  white-space: pre-wrap; word-break: break-word;
}
.chat-hora { font-size: 10.5px; color: var(--rotulo); margin-top: 3px; }
.chat-minha { margin-left: auto; }
.chat-minha .chat-texto { background: var(--laranja); border-color: var(--laranja); color: #fff; }
.chat-minha .chat-autor, .chat-minha .chat-hora { text-align: right; }
.chat-sistema { max-width: 100%; }
.chat-sistema .chat-texto {
  background: transparent; border: 0; border-left: 3px solid var(--linha);
  border-radius: 0; color: var(--texto); font-size: 12.5px; padding: 2px 0 2px 12px;
}
.chat-sistema .chat-hora { padding-left: 15px; }
.chat-envio { display: flex; gap: 10px; margin-top: 12px; }
.chat-envio .campo { flex: 1; }
</style>
