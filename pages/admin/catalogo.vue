<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Catálogo</h1>
        <p>O cadastro vem da Omie. Aqui você completa a foto, o resumo e quem pode pedir.</p>
      </div>
    </div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="carregando" class="carregando">Carregando catálogo...</div>

    <div v-else class="painel">
      <div class="painel-topo">
        <h2>{{ lista.length }} produto(s)</h2>
        <input v-model="busca" class="campo" style="max-width:280px" type="search" placeholder="Buscar no catálogo" />
      </div>
      <TabelaVazia v-if="!filtrados.length" titulo="Catálogo vazio"
        texto="Cadastre os produtos na Omie e use Importar da Omie." />
      <div v-else class="tabela-rolagem">
        <table class="lista">
          <thead><tr><th>Produto</th><th>Tipo</th><th>Quem pode pedir</th><th>Situação</th><th></th></tr></thead>
          <tbody>
            <tr v-for="p in filtrados" :key="p.id">
              <td>
                <div class="produto-linha">
                  <FotoProduto :url="p.photo_url" :titulo="p.title" :tipo="p.type" />
                  <div>
                    <div class="produto-nome">{{ p.title }}</div>
                    <div class="produto-meta">{{ [p.author, p.edition].filter(Boolean).join(' · ') || '—' }}</div>
                  </div>
                </div>
              </td>
              <td><span class="selo selo-neutro">{{ p.type === 'livro' ? 'Livro' : 'Item' }}</span></td>
              <td><span class="selo selo-laranja">{{ rotuloVis(p.visibility) }}</span></td>
              <td><span class="selo" :class="p.active ? 'selo-enviado' : 'selo-neutro'">{{ p.active ? 'Ativo' : 'Inativo' }}</span></td>
              <td><button class="btn btn-neutro btn-p" @click="editar(p)">Editar</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <JanelaModal v-if="form" titulo="Completar produto" @fechar="form = null">
      <div class="aviso" style="margin-bottom:14px">
        Código, título, preço e NCM vêm da Omie e não podem ser alterados aqui.
      </div>
      <div class="grade-2">
        <div class="grupo">
          <label class="rotulo">Código na Omie</label>
          <input :value="form.codigo || '—'" class="campo" disabled />
        </div>
        <div class="grupo">
          <label class="rotulo">Preço de tabela</label>
          <input :value="moeda(form.preco_tabela)" class="campo" disabled />
        </div>
      </div>
      <div class="grupo">
        <label class="rotulo">Título (vem da Omie)</label>
        <input :value="form.title" class="campo" disabled />
      </div>
      <div class="grupo">
        <label class="rotulo">Tipo de produto</label>
        <select v-model="form.type" class="campo">
          <option value="livro">Livro</option>
          <option value="item">Outro item (quadro, oleo de unção, memorial...)</option>
        </select>
      </div>
      <div v-if="form.type === 'livro'" class="grade-2">
        <div class="grupo">
          <label class="rotulo">Autor</label>
          <input v-model="form.author" class="campo" />
        </div>
        <div class="grupo">
          <label class="rotulo">Edição</label>
          <input v-model="form.edition" class="campo" placeholder="Ex.: 3a edição" />
        </div>
      </div>
      <div class="grupo">
        <label class="rotulo">Breve resumo</label>
        <textarea v-model="form.summary" class="campo" placeholder="Do que se trata, em poucas linhas"></textarea>
      </div>
      <div class="grupo">
        <label class="rotulo">Quem pode pedir</label>
        <select v-model="form.visibility" class="campo">
          <option value="ambos">Igrejas da Rede e Pontos de Partida</option>
          <option value="igreja">Somente Igrejas da Rede</option>
          <option value="ponto">Somente Pontos de Partida</option>
        </select>
      </div>
      <div class="grupo">
        <label class="rotulo">Foto do produto</label>
        <img v-if="form.photo_url && !novaFoto" :src="form.photo_url" class="envio-previa" style="margin-bottom:10px" alt="Foto atual" />
        <EnvioFoto texto="Escolher a foto do produto" @arquivo="f => novaFoto = f" />
      </div>
      <label class="linha-acoes" style="gap:8px;cursor:pointer">
        <input v-model="form.active" type="checkbox" />
        <span style="font-size:14px">Produto disponível para pedidos</span>
      </label>
      <template #acoes>
        <button class="btn btn-neutro btn-p" @click="form = null">Cancelar</button>
        <button class="btn btn-principal btn-p" style="width:auto" :disabled="ocupado" @click="salvar">
          {{ ocupado ? 'Salvando...' : 'Salvar' }}
        </button>
      </template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const lista = ref<any[]>([])
const carregando = ref(true)
const busca = ref('')
const form = ref<any>(null)
const novaFoto = ref<File | null>(null)
const ocupado = ref(false)
const msg = ref(''); const erro = ref(false)

const rotuloVis = (v: string) => ({ ambos: 'Todos', igreja: 'Igrejas da Rede', ponto: 'Pontos de Partida' }[v] ?? v)

const filtrados = computed(() => {
  const t = busca.value.trim().toLowerCase()
  if (!t) return lista.value
  return lista.value.filter(p => (p.search_text || '').includes(t))
})

async function carregar() {
  const { data } = await supa.from('products').select('*').order('title')
  lista.value = data ?? []
  carregando.value = false
}
onMounted(carregar)

const moeda = (v: any) =>
  v === null || v === undefined || v === ''
    ? '—'
    : Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

function editar(p: any) { novaFoto.value = null; form.value = { ...p } }

async function salvar() {
  msg.value = ''
  ocupado.value = true
  try {
    let foto = form.value.photo_url
    if (novaFoto.value) {
      const ext = (novaFoto.value.name.split('.').pop() || 'jpg').toLowerCase()
      const caminho = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`
      const up = await supa.storage.from('produtos').upload(caminho, novaFoto.value)
      if (up.error) throw new Error('Não foi possível enviar a foto: ' + up.error.message)
      foto = supa.storage.from('produtos').getPublicUrl(caminho).data.publicUrl
    }
    const dados: any = {
      type: form.value.type,
      author: form.value.type === 'livro' ? (form.value.author || null) : null,
      edition: form.value.type === 'livro' ? (form.value.edition || null) : null,
      summary: form.value.summary || null,
      visibility: form.value.visibility,
      active: form.value.active,
      photo_url: foto
    }
    const { error } = await supa.from('products').update(dados).eq('id', form.value.id)
    if (error) throw new Error(error.message)
    erro.value = false; msg.value = 'Produto salvo.'
    form.value = null; carregar()
  } catch (e: any) {
    erro.value = true; msg.value = e.message
  } finally {
    ocupado.value = false
  }
}
</script>
