<template>
  <div>
    <div class="cabecalho">
      <div><h1>Filiais</h1><p>Igrejas da Rede e Pontos de Partida atendidos pela livraria.</p></div>
      <button class="btn btn-principal btn-p" @click="abrirNova">Cadastrar filial</button>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando filiais...</div>

    <div v-else class="painel">
      <div class="painel-topo">
        <h2>{{ lista.length }} filial(s)</h2>
        <select v-model="filtro" class="campo" style="max-width:220px">
          <option value="">Todas</option>
          <option value="igreja">Igrejas da Rede</option>
          <option value="ponto">Pontos de Partida</option>
        </select>
      </div>
      <TabelaVazia v-if="!filtradas.length" titulo="Nenhuma filial"
        texto="Cadastre a primeira igreja ou ponto de partida." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Nome</th><th>Tipo</th><th>Responsável</th><th>Contato</th><th>Cidade</th><th>Situação</th><th></th></tr></thead>
          <tbody>
            <tr v-for="u in filtradas" :key="u.id">
              <td><strong>{{ u.name }}</strong></td>
              <td><span class="selo selo-laranja">{{ u.type === 'igreja' ? 'Igreja da Rede' : 'Ponto de Partida' }}</span></td>
              <td>{{ u.responsible || '—' }}</td>
              <td>
                <a v-if="u.phone" :href="linkZap(u.phone)" target="_blank" rel="noopener" class="zap">{{ mascaraZap(u.phone) }}</a>
                <span v-else>—</span>
              </td>
              <td>{{ [u.city, u.state].filter(Boolean).join('/') || '—' }}</td>
              <td><span class="selo" :class="u.active ? 'selo-enviado' : 'selo-neutro'">{{ u.active ? 'Ativa' : 'Inativa' }}</span></td>
              <td><button class="btn btn-neutro btn-p" @click="editar(u)">Editar</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="form" :titulo="form.id ? 'Editar filial' : 'Cadastrar filial'" @fechar="form = null">
      <div class="grupo">
        <label class="rotulo">Nome da filial</label>
        <input v-model="form.name" class="campo" placeholder="Ex.: Igreja Central de São Jose" />
      </div>
      <div class="grade-2">
        <div class="grupo">
          <label class="rotulo">Tipo</label>
          <select v-model="form.type" class="campo">
            <option value="igreja">Igreja da Rede</option>
            <option value="ponto">Ponto de Partida</option>
          </select>
        </div>
        <div class="grupo">
          <label class="rotulo">Responsável</label>
          <input v-model="form.responsible" class="campo" />
        </div>
      </div>
      <div class="grade-2">
        <div class="grupo">
          <label class="rotulo">WhatsApp</label>
          <input :value="mascaraZap(form.phone || '')" class="campo" inputmode="numeric"
                 @input="e => form.phone = soDigitos((e.target as HTMLInputElement).value)" />
        </div>
        <div class="grupo">
          <label class="rotulo">Cidade / UF</label>
          <div style="display:flex;gap:8px">
            <input v-model="form.city" class="campo" placeholder="Cidade" />
            <input v-model="form.state" class="campo" style="width:70px" placeholder="UF" maxlength="2" />
          </div>
        </div>
      </div>
      <div class="grupo">
        <label class="rotulo">Endereço</label>
        <input v-model="form.address" class="campo" />
      </div>
      <label class="linha-acoes" style="gap:8px;cursor:pointer">
        <input v-model="form.active" type="checkbox" />
        <span style="font-size:14px">Filial ativa</span>
      </label>
      <template #acoes>
        <button v-if="form.id" class="btn btn-perigo btn-p" style="margin-right:auto" :disabled="ocupado" @click="excluir">
          Excluir filial
        </button>
        <button class="btn btn-neutro btn-p" @click="form = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvar">Salvar</button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const lista = ref<any[]>([])
const carregando = ref(true)
const filtro = ref('')
const form = ref<any>(null)
const ocupado = ref(false)
const msg = ref(''); const erro = ref(false)

const filtradas = computed(() => filtro.value ? lista.value.filter(u => u.type === filtro.value) : lista.value)

async function carregar() {
  const { data } = await supa.from('units').select('*').order('name')
  lista.value = data ?? []
  carregando.value = false
}
onMounted(carregar)

function abrirNova() { form.value = { name: '', type: 'igreja', responsible: '', phone: '', city: '', state: '', address: '', active: true } }
function editar(u: any) { form.value = { ...u } }

async function excluir() {
  if (!confirm(`Excluir a filial "${form.value.name}"? Não dá para desfazer.`)) return
  ocupado.value = true; msg.value = ''
  const { error } = await supa.rpc('fn_delete_unit', { p_id: form.value.id })
  ocupado.value = false
  if (error) { erro.value = true; msg.value = error.message; form.value = null; return }
  erro.value = false; msg.value = 'Filial excluída.'
  form.value = null; carregar()
}

async function salvar() {
  msg.value = ''
  if (!form.value.name?.trim()) { erro.value = true; msg.value = 'Informe o nome da filial.'; return }
  ocupado.value = true
  const dados = { ...form.value }
  const { error } = dados.id
    ? await supa.from('units').update(dados).eq('id', dados.id)
    : await supa.from('units').insert(dados)
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? 'Não foi possível salvar: ' + error.message : 'Filial salva.'
  if (!error) { form.value = null; carregar() }
}
</script>
