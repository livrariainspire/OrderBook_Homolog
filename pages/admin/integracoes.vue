<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Integrações</h1>
        <p>Ligações com a Stone e com a Omie, e a fila do que foi enviado.</p>
      </div>
      <button class="btn btn-principal btn-p" :disabled="ocupado" @click="processar">
        {{ ocupado ? 'Processando...' : 'Processar fila da Omie' }}
      </button>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>

    <div class="painel">
      <div class="painel-topo">
        <h2>Modo de operação</h2>
        <span class="selo" :class="cfg.modo_simulacao === 'true' ? 'selo-fila' : 'selo-enviado'">
          {{ cfg.modo_simulacao === 'true' ? 'Simulação' : 'Produção' }}
        </span>
      </div>
      <div class="painel-corpo">
        <p style="font-size:14px;color:var(--texto);line-height:1.6;margin-bottom:16px">
          Em <strong>simulação</strong>, a cobrança não vai para a maquininha e nada é enviado à Omie —
          o sistema apenas guarda o que teria sido enviado, para conferência.
          Em <strong>produção</strong>, tudo vale de verdade.
        </p>
        <label class="linha-acoes" style="gap:10px;cursor:pointer">
          <input type="checkbox" :checked="cfg.modo_simulacao === 'true'"
                 @change="salvar('modo_simulacao', ($event.target as HTMLInputElement).checked ? 'true' : 'false')" />
          <span style="font-size:14px">Manter em modo simulação</span>
        </label>
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo"><h2>Omie</h2></div>
      <div class="painel-corpo">
        <div class="grade-2">
          <div class="grupo">
            <label class="rotulo">App Key</label>
            <input v-model="cfg.omie_app_key" class="campo" placeholder="Chave de integração da Omie" />
          </div>
          <div class="grupo">
            <label class="rotulo">App Secret</label>
            <input v-model="cfg.omie_app_secret" class="campo" type="password" placeholder="Segredo da Omie" />
          </div>
        </div>
        <div class="grade-2">
          <div class="grupo">
            <label class="rotulo">Código da categoria</label>
            <input v-model="cfg.omie_categoria" class="campo" placeholder="Ex.: 1.01.02" />
          </div>
          <div class="grupo">
            <label class="rotulo">Conta corrente</label>
            <input v-model="cfg.omie_conta" class="campo" placeholder="Código da conta na Omie" />
          </div>
        </div>
        <div class="grade-2">
          <div class="grupo">
            <label class="rotulo">Etapa do pedido</label>
            <input v-model="cfg.omie_etapa" class="campo" placeholder="Ex.: 10" />
          </div>
          <div class="grupo">
            <label class="rotulo">Natureza de operação</label>
            <input v-model="cfg.omie_natureza" class="campo" placeholder="Ex.: 2.99" />
          </div>
        </div>
        <div class="linha-acoes">
          <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvarOmie">
            Salvar dados da Omie
          </button>
          <button class="btn btn-neutro btn-p" :disabled="ocupado" @click="testarOmie">
            Testar conexão
          </button>
        </div>
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo"><h2>Stone</h2></div>
      <div class="painel-corpo">
        <div class="grade-2">
          <div class="grupo">
            <label class="rotulo">Stone Code</label>
            <input v-model="cfg.stone_code" class="campo" placeholder="Código do estabelecimento" />
          </div>
          <div class="grupo">
            <label class="rotulo">CNPJ da matriz</label>
            <input v-model="cfg.stone_cnpj" class="campo" placeholder="00.000.000/0001-00" />
          </div>
        </div>
        <p class="mini" style="margin-bottom:16px">
          A chave secreta da Stone não fica aqui: ela é guardada no servidor, em Edge Functions → Secrets.
          As maquininhas de cada filial são cadastradas em <NuxtLink to="/admin/filiais">Filiais</NuxtLink>.
        </p>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvarStone">
          Salvar dados da Stone
        </button>
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo">
        <h2>Fila da Omie</h2>
        <select v-model="filtro" class="campo" style="max-width:190px">
          <option value="">Tudo</option>
          <option value="pendente">Pendente</option>
          <option value="simulado">Simulado</option>
          <option value="enviado">Enviado</option>
          <option value="erro">Com erro</option>
        </select>
      </div>
      <TabelaVazia v-if="!filaFiltrada.length" titulo="Fila vazia"
        texto="Assim que uma venda for paga, os dados aparecem aqui." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Quando</th><th>Filial</th><th>Situação</th><th>Tentativas</th><th></th></tr></thead>
          <tbody>
            <tr v-for="f in filaFiltrada" :key="f.id">
              <td>{{ dataHora(f.created_at) }}</td>
              <td><strong>{{ f.unit_name }}</strong></td>
              <td>
                <span class="selo" :class="corFila(f.status)">{{ rotuloFila(f.status) }}</span>
                <div v-if="f.last_error" class="mini" style="color:var(--vermelho)">{{ f.last_error }}</div>
              </td>
              <td>{{ f.attempts }}</td>
              <td class="acoes-celula">
                <button class="btn btn-neutro btn-p" @click="ver(f)">Ver dados</button>
                <button v-if="f.status !== 'pendente'" class="btn btn-contorno btn-p" @click="reenviar(f)">Reenviar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="aberto" titulo="O que vai para a Omie" @fechar="aberto = null">
      <p class="mini" style="margin-bottom:12px">{{ aberto.unit_name }} · {{ dataHora(aberto.created_at) }}</p>
      <pre class="json">{{ JSON.stringify(aberto.payload, null, 2) }}</pre>
      <template v-if="aberto.response">
        <h4 style="font-size:13px;margin:18px 0 8px">Resposta</h4>
        <pre class="json">{{ JSON.stringify(aberto.response, null, 2) }}</pre>
      </template>
      <template #acoes><button class="btn btn-neutro btn-p" @click="aberto = null">Fechar</button></template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const cfg = ref<any>({})
const fila = ref<any[]>([])
const filtro = ref('')
const aberto = ref<any>(null)
const msg = ref(''); const erro = ref(false); const ocupado = ref(false)

const filaFiltrada = computed(() => filtro.value ? fila.value.filter(f => f.status === filtro.value) : fila.value)

const rotuloFila = (s: string) => ({
  pendente: 'Aguardando envio', simulado: 'Simulado', enviado: 'Enviado', erro: 'Com erro'
}[s] ?? s)

const corFila = (s: string) => ({
  pendente: 'selo-fila', simulado: 'selo-atendimento', enviado: 'selo-enviado', erro: 'selo-cancelado'
}[s] ?? 'selo-neutro')

async function carregar() {
  const [s, q] = await Promise.all([
    supa.from('settings').select('*'),
    supa.from('omie_queue').select('*').order('created_at', { ascending: false }).limit(200)
  ])
  const c: any = {}
  ;(s.data ?? []).forEach((r: any) => { c[r.key] = r.value })
  cfg.value = c
  fila.value = q.data ?? []
}
onMounted(carregar)

async function salvar(chave: string, valor: string | null) {
  const { error } = await supa.rpc('fn_save_setting', { p_key: chave, p_value: valor })
  if (error) { erro.value = true; msg.value = error.message; return false }
  cfg.value[chave] = valor
  return true
}

async function salvarVarios(chaves: string[], aviso: string) {
  ocupado.value = true; msg.value = ''
  for (const k of chaves) {
    const ok = await salvar(k, cfg.value[k] || null)
    if (!ok) { ocupado.value = false; return }
  }
  ocupado.value = false
  erro.value = false; msg.value = aviso
}

const salvarOmie = () => salvarVarios(
  ['omie_app_key', 'omie_app_secret', 'omie_categoria', 'omie_conta', 'omie_etapa', 'omie_natureza'],
  'Dados da Omie salvos.')

const salvarStone = () => salvarVarios(['stone_code', 'stone_cnpj'], 'Dados da Stone salvos.')

async function testarOmie() {
  ocupado.value = true; msg.value = ''
  try {
    const r = await chamarApi('/omie/testar')
    erro.value = !r.ok
    msg.value = r.mensagem
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}

async function processar() {
  ocupado.value = true; msg.value = ''
  try {
    const r = await chamarApi('/omie/processar', { limite: 30 })
    erro.value = false
    msg.value = r.processados
      ? `${r.processados} item(ns) processado(s)${r.simulado ? ' em modo simulação' : ''}.`
      : 'Nada pendente na fila.'
    carregar()
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}

async function reenviar(f: any) {
  await supa.rpc('fn_omie_reenviar', { p_id: f.id })
  carregar()
}

function ver(f: any) { aberto.value = f }
</script>

<style scoped>
.json {
  background: var(--campo); border: 1px solid var(--linha); border-radius: 10px;
  padding: 14px; font-size: 11.5px; line-height: 1.55; overflow-x: auto;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--tinta); margin: 0;
  white-space: pre-wrap; word-break: break-word;
}
</style>
