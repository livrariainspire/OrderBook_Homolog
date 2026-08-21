<template>
  <div>
    <div class="cabecalho">
      <div><h1>Vendas</h1><p>Histórico das baixas registradas pela filial.</p></div>
      <NuxtLink to="/vendas/nova" class="btn btn-principal btn-p">Registrar venda</NuxtLink>
    </div>

    <div v-if="carregando" class="carregando">Carregando vendas...</div>

    <template v-else>
      <div class="resumos">
        <div class="resumo">
          <div class="resumo-rotulo">Total vendido</div>
          <div class="resumo-valor">{{ moeda(soma) }}</div>
          <div class="resumo-nota">{{ vendas.length }} vendas registradas</div>
        </div>
      </div>

      <div class="painel">
        <TabelaVazia v-if="!vendas.length" titulo="Nenhuma venda registrada"
          texto="Registre a primeira venda para começar a controlar o estoque." />
        <div v-else class="tabela-rolagem">
          <table class="lista">
            <thead><tr><th>Código</th><th>Data</th><th>Registrada por</th><th>Total</th><th></th></tr></thead>
            <tbody>
              <tr v-for="v in vendas" :key="v.id">
                <td><strong>{{ v.code }}</strong></td>
                <td>{{ dataHora(v.created_at) }}</td>
                <td>{{ v.created_by_name }}</td>
                <td><strong>{{ moeda(v.total) }}</strong></td>
                <td><button class="btn btn-neutro btn-p" @click="abrir(v)">Detalhes</button></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <JanelaModal v-if="aberta" :titulo="`Venda ${aberta.code}`" @fechar="aberta = null">
      <p class="mini" style="margin-bottom:14px">{{ dataHora(aberta.created_at) }} · {{ aberta.created_by_name }}</p>
      <div v-if="aberta.note" class="aviso aviso-info">{{ aberta.note }}</div>
      <table class="lista" style="font-size:13px">
        <thead><tr><th>Produto</th><th>Qtd</th><th>Unitário</th><th>Subtotal</th></tr></thead>
        <tbody>
          <tr v-for="i in itens" :key="i.id">
            <td><strong>{{ i.product_title }}</strong></td>
            <td>{{ i.qty }}</td>
            <td>{{ moeda(i.unit_price) }}</td>
            <td>{{ moeda(i.subtotal) }}</td>
          </tr>
        </tbody>
      </table>
      <div style="margin-top:18px">
        <a v-if="urlComprovante" :href="urlComprovante" target="_blank" rel="noopener">
          <img :src="urlComprovante" class="envio-previa" alt="Comprovante da venda" />
        </a>
        <p v-else class="mini">Comprovante indisponível.</p>
      </div>
      <template #acoes><button class="btn btn-neutro btn-p" @click="aberta = null">Fechar</button></template>
    </JanelaModal>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const vendas = ref<any[]>([])
const carregando = ref(true)
const aberta = ref<any>(null)
const itens = ref<any[]>([])
const urlComprovante = ref('')

const soma = computed(() => vendas.value.reduce((s, v) => s + Number(v.total), 0))

onMounted(async () => {
  const { data } = await supa.from('sales').select('*').order('created_at', { ascending: false })
  vendas.value = data ?? []
  carregando.value = false
})

async function abrir(v: any) {
  aberta.value = v; urlComprovante.value = ''
  const { data } = await supa.from('sale_items').select('*').eq('sale_id', v.id)
  itens.value = data ?? []
  if (v.receipt_path) {
    const { data: sig } = await supa.storage.from('comprovantes').createSignedUrl(v.receipt_path, 3600)
    urlComprovante.value = sig?.signedUrl ?? ''
  }
}
</script>
