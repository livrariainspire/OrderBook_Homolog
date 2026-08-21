<template>
  <div>
    <div class="cabecalho">
      <div>
        <h1>Omie</h1>
        <p>Estoque da livraria na Omie e ligação com o catálogo do Order Book.</p>
      </div>
      <button class="btn btn-principal btn-p" :disabled="carregando" @click="carregar">
        {{ carregando ? 'Consultando...' : 'Atualizar' }}
      </button>
    </div>
    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>
    <div v-if="dados?.aviso_estoque" class="aviso aviso-erro">
      A Omie respondeu o cadastro de produtos, mas recusou a consulta de saldo:
      {{ dados.aviso_estoque }}
    </div>

    <div v-if="carregando" class="carregando">Consultando a Omie...</div>

    <template v-else-if="dados">
      <div class="grade-3" style="margin-bottom:16px">
        <div class="cartao">
          <span class="rotulo">Produtos na Omie</span>
          <strong style="font-size:28px">{{ dados.total_omie }}</strong>
        </div>
        <div class="cartao">
          <span class="rotulo">Produtos no catálogo</span>
          <strong style="font-size:28px">{{ dados.total_catalogo }}</strong>
        </div>
        <div class="cartao">
          <span class="rotulo">Ainda sem ligação</span>
          <strong style="font-size:28px">{{ dados.so_no_order_book.length }}</strong>
        </div>
      </div>

      <div class="painel">
        <div class="painel-topo">
          <h2>Estoque na Omie</h2>
          <input v-model="busca" class="campo" style="max-width:260px" placeholder="Buscar produto" />
        </div>

        <TabelaVazia v-if="!linhas.length" titulo="Nada encontrado"
          texto="Nenhum produto da Omie corresponde à busca." />

        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr>
                <th>Código</th><th>Descrição</th><th>Saldo</th>
                <th>Valor</th><th>Catálogo</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="l in linhas" :key="l.omie_id">
                <td><strong>{{ l.codigo || '—' }}</strong></td>
                <td>{{ l.descricao }}</td>
                <td>
                  <span v-if="l.saldo === null" class="selo selo-neutro">sem dado</span>
                  <strong v-else>{{ l.saldo }}</strong>
                </td>
                <td>{{ moeda(l.valor_unitario) }}</td>
                <td>
                  <span v-if="l.ligado_a" class="selo selo-enviado">{{ l.ligado_a.codigo }}</span>
                  <span v-else class="selo selo-neutro">não ligado</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel" style="margin-top:16px">
        <div class="painel-topo">
          <h2>Disponível para enviar às filiais</h2>
          <span class="rotulo">saldo na Omie menos o que já está nas filiais</span>
        </div>
        <TabelaVazia v-if="!dados.quadro?.length" titulo="Nenhum produto ligado"
          texto="Ligue os produtos à Omie para acompanhar o disponível." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead>
              <tr><th>Código</th><th>Título</th><th>Na Omie</th>
                  <th>Nas filiais</th><th>Disponível</th></tr>
            </thead>
            <tbody>
              <tr v-for="q in dados.quadro" :key="q.product_id">
                <td><strong>{{ q.codigo }}</strong></td>
                <td>{{ q.titulo }}</td>
                <td>{{ q.saldo_omie }}</td>
                <td>{{ q.alocado }}</td>
                <td>
                  <span class="selo" :class="Number(q.disponivel) > 0 ? 'selo-enviado' : 'selo-neutro'">
                    {{ q.disponivel }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="painel" style="margin-top:16px">
        <div class="painel-topo">
          <h2>No Order Book, mas não na Omie</h2>
          <div v-if="dados.so_no_order_book.length" style="display:flex;gap:8px;align-items:center">
            <label class="rotulo">Quantos enviar</label>
            <input v-model.number="quantos" type="number" min="1" max="50"
                   class="campo" style="max-width:90px" />
            <button class="btn btn-principal btn-p" :disabled="enviando" @click="enviar">
              {{ enviando ? 'Enviando...' : 'Criar na Omie' }}
            </button>
          </div>
        </div>

        <div v-if="resultado" class="aviso"
             :class="resultado.falhas.length ? 'aviso-erro' : 'aviso-ok'">
          {{ resultado.criados.length }} produto(s) criado(s) na Omie.
          <template v-if="resultado.falhas.length">
            {{ resultado.falhas.length }} não passou(ram).
          </template>
        </div>

        <div v-if="resultado?.falhas.length" class="tabela-rolagem" style="margin-bottom:12px">
          <table class="lista">
            <thead><tr><th>Código</th><th>Título</th><th>Motivo</th></tr></thead>
            <tbody>
              <tr v-for="(f, i) in resultado.falhas" :key="i">
                <td><strong>{{ f.codigo || '—' }}</strong></td>
                <td>{{ f.title }}</td>
                <td>{{ f.motivo }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <TabelaVazia v-if="!dados.so_no_order_book.length" titulo="Tudo ligado"
          texto="Todo o catálogo já tem produto correspondente na Omie." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Código</th><th>Título</th></tr></thead>
            <tbody>
              <tr v-for="p in dados.so_no_order_book" :key="p.id">
                <td><strong>{{ p.codigo || '—' }}</strong></td>
                <td>{{ p.title }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
const carregando = ref(false)
const msg = ref('')
const erro = ref(false)
const busca = ref('')
const dados = ref<any>(null)
const quantos = ref(10)
const enviando = ref(false)
const resultado = ref<any>(null)

async function enviar () {
  if (!confirm(`Isto vai CRIAR ${quantos.value} produto(s) na sua conta da Omie. Continuar?`)) return
  enviando.value = true
  msg.value = ''
  erro.value = false
  resultado.value = null
  try {
    resultado.value = await chamarApi('/omie/criar-produtos', { limite: quantos.value })
    await carregar()
  } catch (e: any) {
    erro.value = true
    msg.value = e.message || 'Não foi possível criar os produtos.'
  } finally {
    enviando.value = false
  }
}

const moeda = (v: any) =>
  v === null || v === undefined || v === ''
    ? '—'
    : Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

const linhas = computed(() => {
  const t = busca.value.trim().toLowerCase()
  const todas = dados.value?.linhas ?? []
  if (!t) return todas
  return todas.filter((l: any) =>
    String(l.descricao ?? '').toLowerCase().includes(t) ||
    String(l.codigo ?? '').toLowerCase().includes(t))
})

async function carregar () {
  carregando.value = true
  msg.value = ''
  erro.value = false
  try {
    dados.value = await chamarApi('/omie/estoque')
  } catch (e: any) {
    erro.value = true
    msg.value = e.message || 'Não foi possível consultar a Omie.'
  } finally {
    carregando.value = false
  }
}

onMounted(carregar)
</script>
