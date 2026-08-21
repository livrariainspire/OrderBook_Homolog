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
          <thead><tr><th>Nome</th><th>Tipo</th><th>Responsável</th><th>Contato</th><th>Cidade</th><th>Maquininhas</th><th>Situação</th><th></th></tr></thead>
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
              <td>
                <span v-if="contaMaquinas(u.id)" class="selo selo-neutro">{{ contaMaquinas(u.id) }}</span>
                <span v-else class="mini">nenhuma</span>
              </td>
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
      <div class="grade-2">
        <div class="grupo">
          <label class="rotulo">CNPJ (opcional)</label>
          <input v-model="form.cnpj" class="campo" placeholder="00.000.000/0001-00" />
        </div>
        <div class="grupo">
          <label class="rotulo">Código do cliente na Omie (opcional)</label>
          <input v-model="form.omie_client_id" class="campo" placeholder="Deixe vazio se ainda não souber" />
        </div>
      </div>
      <label class="linha-acoes" style="gap:8px;cursor:pointer">
        <input v-model="form.active" type="checkbox" />
        <span style="font-size:14px">Filial ativa</span>
      </label>

      <template v-if="form.id">
        <hr class="divisor" />
        <h4 style="font-size:14px;margin-bottom:6px">Maquininhas desta filial</h4>
        <p class="mini" style="margin-bottom:14px">
          O número de série fica embaixo da maquininha ou no menu de informações dela.
          É por ele que a cobrança chega na máquina certa.
        </p>

        <div v-if="erroMaquina" class="aviso aviso-erro">{{ erroMaquina }}</div>

        <div v-for="m in maquinas" :key="m.id" class="carrinho-item">
          <div class="cresce">
            <div class="produto-nome">{{ m.serial }}</div>
            <div class="produto-meta">{{ m.nickname || 'Sem apelido' }}</div>
          </div>
          <span class="selo" :class="m.active ? 'selo-enviado' : 'selo-neutro'">
            {{ m.active ? 'Ativa' : 'Inativa' }}
          </span>
          <button class="btn-linha" @click="alternarMaquina(m)">
            {{ m.active ? 'Desativar' : 'Ativar' }}
          </button>
          <button class="btn-linha" style="color:var(--vermelho)" @click="excluirMaquina(m)">Excluir</button>
        </div>

        <p v-if="!maquinas.length" class="mini" style="margin-bottom:14px">
          Nenhuma maquininha cadastrada nesta filial.
        </p>

        <div class="grade-2" style="margin-top:14px">
          <div class="grupo">
            <label class="rotulo">Número de série</label>
            <input v-model="novaMaquina.serial" class="campo" placeholder="Ex.: 6C582505"
                   @keyup.enter="salvarMaquina" />
          </div>
          <div class="grupo">
            <label class="rotulo">Apelido (opcional)</label>
            <input v-model="novaMaquina.nickname" class="campo" placeholder="Ex.: Balcão da frente"
                   @keyup.enter="salvarMaquina" />
          </div>
        </div>
        <button class="btn btn-contorno btn-p" style="width:auto" :disabled="ocupado" @click="salvarMaquina">
          Adicionar maquininha
        </button>
      </template>
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
const maquinas = ref<any[]>([])
const todasMaquinas = ref<any[]>([])
const novaMaquina = ref<any>({ serial: '', nickname: '' })
const erroMaquina = ref('')
const msg = ref(''); const erro = ref(false)

const filtradas = computed(() => filtro.value ? lista.value.filter(u => u.type === filtro.value) : lista.value)

async function carregar() {
  const [u, d] = await Promise.all([
    supa.from('units').select('*').order('name'),
    supa.from('unit_devices').select('*').order('serial')
  ])
  lista.value = u.data ?? []
  todasMaquinas.value = d.data ?? []
  carregando.value = false
}

const contaMaquinas = (id: string) =>
  todasMaquinas.value.filter(m => m.unit_id === id && m.active).length

async function carregarMaquinas() {
  if (!form.value?.id) { maquinas.value = []; return }
  const { data } = await supa.from('unit_devices').select('*')
    .eq('unit_id', form.value.id).order('serial')
  maquinas.value = data ?? []
}

async function salvarMaquina() {
  erroMaquina.value = ''
  if (!novaMaquina.value.serial?.trim()) {
    erroMaquina.value = 'Informe o número de série da maquininha.'; return
  }
  ocupado.value = true
  const { error } = await supa.rpc('fn_save_device', {
    p_id: null,
    p_unit: form.value.id,
    p_serial: novaMaquina.value.serial,
    p_nickname: novaMaquina.value.nickname || null,
    p_active: true,
    p_note: null
  })
  ocupado.value = false
  if (error) { erroMaquina.value = error.message; return }
  novaMaquina.value = { serial: '', nickname: '' }
  await carregarMaquinas(); await carregar()
}

async function alternarMaquina(m: any) {
  erroMaquina.value = ''
  const { error } = await supa.rpc('fn_save_device', {
    p_id: m.id, p_unit: m.unit_id, p_serial: m.serial,
    p_nickname: m.nickname, p_active: !m.active, p_note: m.note
  })
  if (error) { erroMaquina.value = error.message; return }
  await carregarMaquinas(); await carregar()
}

async function excluirMaquina(m: any) {
  if (!confirm(`Excluir a maquininha ${m.serial}?`)) return
  erroMaquina.value = ''
  const { error } = await supa.rpc('fn_delete_device', { p_id: m.id })
  if (error) { erroMaquina.value = error.message; return }
  await carregarMaquinas(); await carregar()
}
onMounted(carregar)

function abrirNova() {
  erroMaquina.value = ''; maquinas.value = []
  novaMaquina.value = { serial: '', nickname: '' }
  form.value = { name: '', type: 'igreja', responsible: '', phone: '', city: '', state: '', address: '', active: true }
}

function editar(u: any) {
  erroMaquina.value = ''
  novaMaquina.value = { serial: '', nickname: '' }
  form.value = { ...u }
  carregarMaquinas()
}

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
