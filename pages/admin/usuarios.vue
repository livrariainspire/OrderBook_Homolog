<template>
  <div>
    <div class="cabecalho">
      <div><h1>Usuários</h1><p>Aprove cadastros, defina o perfil e vincule cada pessoa a sua filial.</p></div>
      <button class="btn btn-principal btn-p" @click="abrirNovo">Criar usuário</button>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando usuários...</div>

    <template v-else>
      <div class="painel">
        <div class="painel-topo"><h2>Aguardando aprovação ({{ pendentes.length }})</h2></div>
        <TabelaVazia v-if="!pendentes.length" titulo="Nenhum cadastro pendente" texto="Novos cadastros aparecem aqui." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Nome</th><th>E-mail</th><th>WhatsApp</th><th>Cadastrado</th><th></th></tr></thead>
            <tbody>
              <tr v-for="u in pendentes" :key="u.id">
                <td><strong>{{ u.full_name || '—' }}</strong></td>
                <td>{{ u.email }}</td>
                <td><a :href="linkZap(u.whatsapp)" target="_blank" rel="noopener" class="zap">{{ mascaraZap(u.whatsapp) }}</a></td>
                <td>{{ dataHora(u.created_at) }}</td>
                <td class="acoes-celula">
                  <button class="btn btn-principal btn-p" @click="abrirEdicao(u, true)">Aprovar</button>
                  <button class="btn btn-perigo btn-p" @click="recusar(u)">Recusar</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>Todos os usuários</h2>
          <input v-model="busca" class="campo" style="max-width:260px" type="search" placeholder="Buscar por nome ou e-mail" />
        </div>
        <div class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Nome</th><th>Contato</th><th>Perfil</th><th>Filial</th><th>Situação</th><th></th></tr></thead>
            <tbody>
              <tr v-for="u in filtrados" :key="u.id">
                <td><strong>{{ u.full_name || '—' }}</strong><div class="mini">{{ u.email }}</div></td>
                <td><a v-if="u.whatsapp" :href="linkZap(u.whatsapp)" target="_blank" rel="noopener" class="zap">{{ mascaraZap(u.whatsapp) }}</a><span v-else>—</span></td>
                <td>{{ rotuloPerfil(u.role) }}</td>
                <td>{{ nomeUnidade(u.unit_id) }}</td>
                <td><span class="selo" :class="classeSelo(u.status)">{{ rotuloSituacao(u.status) }}</span></td>
                <td class="acoes-celula">
                  <button class="btn btn-neutro btn-p" @click="abrirEdicao(u)">Editar</button>
                  <button class="btn btn-neutro btn-p" @click="abrirSenha(u)">Senha</button>
                  <button v-if="u.status === 'aprovado'" class="btn btn-neutro btn-p" @click="desativar(u)">Desativar</button>
                  <button class="btn btn-perigo btn-p" @click="abrirExclusao(u)">Excluir</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- cadastro completo -->
    <JanelaModal v-if="alvo" :titulo="`Cadastro de ${alvo.full_name || alvo.email}`" @fechar="alvo = null">
      <div v-if="erroJanela" class="aviso aviso-erro">{{ erroJanela }}</div>

      <div class="grupo">
        <label class="rotulo">Nome completo</label>
        <input v-model="form.full_name" class="campo" />
      </div>
      <div class="grade-2">
        <div class="grupo">
          <label class="rotulo">E-mail</label>
          <input v-model="form.email" class="campo" type="email" />
        </div>
        <div class="grupo">
          <label class="rotulo">WhatsApp</label>
          <input :value="mascaraZap(form.whatsapp)" class="campo" inputmode="numeric"
                 @input="e => form.whatsapp = soDigitos((e.target as HTMLInputElement).value)" />
        </div>
      </div>
      <div class="grade-2">
        <div class="grupo">
          <label class="rotulo">Perfil de acesso</label>
          <select v-model="form.role" class="campo">
            <option value="">Selecione</option>
            <option value="admin">Administração</option>
            <option value="atendente">Atendimento</option>
            <option value="igreja">Igreja da Rede</option>
            <option value="ponto">Ponto de Partida</option>
          </select>
        </div>
        <div class="grupo">
          <label class="rotulo">Situação</label>
          <select v-model="form.status" class="campo">
            <option value="aprovado">Ativo</option>
            <option value="pendente">Aguardando aprovação</option>
            <option value="inativo">Inativo</option>
            <option value="rejeitado">Recusado</option>
          </select>
        </div>
      </div>
      <div v-if="form.role === 'igreja' || form.role === 'ponto'" class="grupo">
        <label class="rotulo">Filial</label>
        <select v-model="form.unit_id" class="campo">
          <option value="">Selecione a filial</option>
          <option v-for="u in filiaisDoTipo" :key="u.id" :value="u.id">{{ u.name }}</option>
        </select>
        <p v-if="!filiaisDoTipo.length" class="mini" style="margin-top:8px">
          Nenhuma filial deste tipo cadastrada. Cadastre em "Filiais".
        </p>
      </div>
      <div class="grupo">
        <label class="rotulo">Observação interna (opcional)</label>
        <input v-model="form.note" class="campo" placeholder="Anotação visível só para a administração" />
      </div>

      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="alvo = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvarCadastro">
          {{ ocupado ? 'Salvando...' : 'Salvar cadastro' }}
        </button>
      </template>
    </JanelaModal>

    <!-- senha -->
    <JanelaModal v-if="alvoSenha" :titulo="`Nova senha de ${alvoSenha.full_name || alvoSenha.email}`" @fechar="alvoSenha = null">
      <div class="grupo">
        <label class="rotulo">Nova senha</label>
        <input v-model="senhaNova" class="campo" placeholder="Mínimo 8 caracteres" />
      </div>
      <p class="mini">Informe a nova senha para a pessoa pelo WhatsApp. Ela pode trocar depois em "Minha conta".</p>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="alvoSenha = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvarSenha">Definir senha</button>
      </template>
    </JanelaModal>

    <!-- excluir usuario -->
    <JanelaModal v-if="alvoExcluir" :titulo="`Excluir ${alvoExcluir.full_name || alvoExcluir.email}`" @fechar="alvoExcluir = null">
      <p style="font-size:14px;line-height:1.6;color:var(--texto)">
        A conta e o acesso serão apagados definitivamente. Pedidos, vendas e registros
        feitos por esta pessoa continuam no histórico com o nome dela.
      </p>
      <div v-if="resumoExclusao" class="painel" style="margin-top:16px">
        <div class="painel-corpo pilha">
          <div class="entre"><span class="mini">Pedidos criados</span><strong>{{ resumoExclusao.pedidos }}</strong></div>
          <div class="entre"><span class="mini">Vendas registradas</span><strong>{{ resumoExclusao.vendas }}</strong></div>
          <div class="entre"><span class="mini">Pedidos atendidos</span><strong>{{ resumoExclusao.atendimentos }}</strong></div>
        </div>
      </div>
      <div class="grupo" style="margin-top:18px">
        <label class="rotulo">Para confirmar, digite EXCLUIR</label>
        <input v-model="confirmaExclusao" class="campo" placeholder="EXCLUIR" />
      </div>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="alvoExcluir = null">Cancelar</button>
        <button class="btn btn-perigo btn-p" style="width:auto"
                :disabled="ocupado || confirmaExclusao.trim().toUpperCase() !== 'EXCLUIR'" @click="excluirUsuario">
          {{ ocupado ? 'Excluindo...' : 'Excluir definitivamente' }}
        </button>
      </template>
    </JanelaModal>

    <!-- criar usuario -->
    <JanelaModal v-if="novo" titulo="Criar usuário" @fechar="novo = null">
      <div class="grupo"><label class="rotulo">Nome completo</label><input v-model="novo.full_name" class="campo" /></div>
      <div class="grupo"><label class="rotulo">E-mail</label><input v-model="novo.email" class="campo" type="email" /></div>
      <div class="grupo">
        <label class="rotulo">WhatsApp</label>
        <input :value="mascaraZap(novo.whatsapp)" class="campo" inputmode="numeric"
               @input="e => novo.whatsapp = soDigitos((e.target as HTMLInputElement).value)" />
      </div>
      <div class="grupo"><label class="rotulo">Senha provisoria</label><input v-model="novo.password" class="campo" placeholder="Mínimo 8 caracteres" /></div>
      <div class="grupo">
        <label class="rotulo">Perfil</label>
        <select v-model="novo.role" class="campo">
          <option value="">Deixar pendente</option>
          <option value="admin">Administração</option>
          <option value="atendente">Atendimento</option>
          <option value="igreja">Igreja da Rede</option>
          <option value="ponto">Ponto de Partida</option>
        </select>
      </div>
      <div v-if="novo.role === 'igreja' || novo.role === 'ponto'" class="grupo">
        <label class="rotulo">Filial</label>
        <select v-model="novo.unit_id" class="campo">
          <option value="">Selecione</option>
          <option v-for="u in unidades.filter(x => x.type === novo.role)" :key="u.id" :value="u.id">{{ u.name }}</option>
        </select>
      </div>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="novo = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="criar">Criar usuário</button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const usuarios = ref<any[]>([])
const unidades = ref<any[]>([])
const carregando = ref(true)
const busca = ref('')
const msg = ref(''); const erro = ref(false); const ocupado = ref(false)

const alvo = ref<any>(null)
const form = ref<any>({})
const erroJanela = ref('')
const alvoSenha = ref<any>(null); const senhaNova = ref('')
const novo = ref<any>(null)
const alvoExcluir = ref<any>(null)
const resumoExclusao = ref<any>(null)
const confirmaExclusao = ref('')

const pendentes = computed(() => usuarios.value.filter(u => u.status === 'pendente'))
const filtrados = computed(() => {
  const t = busca.value.trim().toLowerCase()
  if (!t) return usuarios.value
  return usuarios.value.filter(u => `${u.full_name} ${u.email}`.toLowerCase().includes(t))
})
const filiaisDoTipo = computed(() => unidades.value.filter(u => u.type === form.value.role))
const nomeUnidade = (id: string | null) => unidades.value.find(u => u.id === id)?.name ?? '—'

async function carregar() {
  const [u, un] = await Promise.all([
    supa.from('profiles').select('*').order('created_at', { ascending: false }),
    supa.from('units').select('*').order('name')
  ])
  usuarios.value = u.data ?? []
  unidades.value = un.data ?? []
  carregando.value = false
}
onMounted(carregar)

function abrirEdicao(u: any, aprovando = false) {
  alvo.value = u
  erroJanela.value = ''
  form.value = {
    full_name: u.full_name ?? '',
    email: u.email ?? '',
    whatsapp: u.whatsapp ?? '',
    role: u.role ?? '',
    unit_id: u.unit_id ?? '',
    status: aprovando ? 'aprovado' : u.status,
    note: u.note ?? ''
  }
}
function abrirSenha(u: any) { alvoSenha.value = u; senhaNova.value = '' }
function abrirNovo() { novo.value = { full_name: '', email: '', whatsapp: '', password: '', role: '', unit_id: '' } }

async function salvarCadastro() {
  erroJanela.value = ''
  const f = form.value

  if (!f.full_name.trim()) { erroJanela.value = 'Informe o nome completo.'; return }
  if (!f.email.trim()) { erroJanela.value = 'Informe o e-mail.'; return }
  if (f.status === 'aprovado' && !f.role) { erroJanela.value = 'Selecione o perfil de acesso.'; return }
  if (['igreja', 'ponto'].includes(f.role) && !f.unit_id) { erroJanela.value = 'Selecione a filial.'; return }

  ocupado.value = true
  try {
    // o e-mail de acesso vive fora da tabela de perfis
    if (f.email.trim().toLowerCase() !== (alvo.value.email ?? '').toLowerCase()) {
      await chamarApi('/update-user', { user_id: alvo.value.id, email: f.email.trim() })
    }

    const { error } = await supa.from('profiles').update({
      full_name: f.full_name.trim(),
      email: f.email.trim().toLowerCase(),
      whatsapp: soDigitos(f.whatsapp),
      role: f.role || null,
      unit_id: ['igreja', 'ponto'].includes(f.role) ? f.unit_id : null,
      status: f.status,
      note: f.note || null,
      approved_at: f.status === 'aprovado' ? new Date().toISOString() : null
    }).eq('id', alvo.value.id)
    if (error) throw new Error(error.message)

    erro.value = false; msg.value = 'Cadastro atualizado.'
    alvo.value = null; carregar()
  } catch (e: any) {
    erroJanela.value = e.message
  } finally {
    ocupado.value = false
  }
}

async function recusar(u: any) {
  if (!confirm(`Recusar o cadastro de ${u.full_name || u.email}?`)) return
  await supa.rpc('fn_set_user_status', { p_user: u.id, p_status: 'rejeitado', p_note: null })
  carregar()
}

async function desativar(u: any) {
  if (!confirm(`Desativar o acesso de ${u.full_name || u.email}?`)) return
  await supa.rpc('fn_set_user_status', { p_user: u.id, p_status: 'inativo', p_note: null })
  carregar()
}

async function abrirExclusao(u: any) {
  alvoExcluir.value = u; confirmaExclusao.value = ''; resumoExclusao.value = null
  const { data } = await supa.rpc('fn_check_user_delete', { p_id: u.id })
  resumoExclusao.value = Array.isArray(data) ? data[0] : data
}

async function excluirUsuario() {
  msg.value = ''; ocupado.value = true
  try {
    await chamarApi('/delete-user', { user_id: alvoExcluir.value.id })
    erro.value = false; msg.value = 'Usuário excluído.'
    alvoExcluir.value = null; carregar()
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}

async function salvarSenha() {
  msg.value = ''
  if (senhaNova.value.length < 8) { erro.value = true; msg.value = 'A senha precisa ter ao menos 8 caracteres.'; return }
  ocupado.value = true
  try {
    await chamarApi('/set-password', { user_id: alvoSenha.value.id, password: senhaNova.value })
    erro.value = false; msg.value = 'Senha definida. Avise a pessoa pelo WhatsApp.'
    alvoSenha.value = null
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}

async function criar() {
  msg.value = ''; ocupado.value = true
  try {
    await chamarApi('/create-user', novo.value)
    erro.value = false; msg.value = 'Usuário criado.'
    novo.value = null; carregar()
  } catch (e: any) { erro.value = true; msg.value = e.message }
  ocupado.value = false
}
</script>
