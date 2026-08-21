<template>
  <div class="app">
    <header class="topo">
      <div class="topo-interno">
        <MarcaInspire />
        <div class="topo-usuario">
          <div style="text-align:right">
            <strong>{{ perfil?.full_name || perfil?.email }}</strong>
            <span>{{ rotuloPerfil(perfil?.role) }}<template v-if="unidade"> · {{ unidade.name }}</template></span>
          </div>
          <SinoAvisos />
          <button class="btn btn-neutro btn-p" @click="sair">Sair</button>
        </div>
      </div>
    </header>

    <nav class="menu">
      <div class="menu-interno">
        <NuxtLink v-for="l in links" :key="l.para" :to="l.para" :class="{ ativo: ativo(l.para) }">
          {{ l.nome }}
        </NuxtLink>
      </div>
    </nav>

    <main class="conteudo"><slot /></main>
  </div>
</template>

<script setup lang="ts">
const sessao = useSessao()
const rota = useRoute()
const perfil = computed(() => sessao.value.perfil)
const unidade = computed(() => sessao.value.unidade)

const links = computed(() => {
  const r = perfil.value?.role
  if (r === 'admin') return [
    { nome: 'Painel', para: '/painel' },
    { nome: 'Pedidos', para: '/admin/pedidos' },
    { nome: 'Catálogo', para: '/admin/catalogo' },
    { nome: 'Filiais', para: '/admin/filiais' },
    { nome: 'Usuários', para: '/admin/usuarios' },
    { nome: 'Relatórios', para: '/relatorios' },
    { nome: 'Omie', para: '/admin/omie' },
    { nome: 'Registros', para: '/admin/registros' }
  ]
  if (r === 'atendente') return [
    { nome: 'Painel', para: '/painel' },
    { nome: 'Fila de pedidos', para: '/fila' },
    { nome: 'Meus atendimentos', para: '/atendimentos' },
    { nome: 'Relatórios', para: '/relatorios' },
    { nome: 'Minha conta', para: '/conta' }
  ]
  return [
    { nome: 'Painel', para: '/painel' },
    { nome: 'Fazer pedido', para: '/pedidos/novo' },
    { nome: 'Meus pedidos', para: '/pedidos' },
    { nome: 'Meu estoque', para: '/estoque' },
    { nome: 'Vendas', para: '/vendas' },
    { nome: 'Maquininha', para: '/maquininha' },
    { nome: 'Minha conta', para: '/conta' }
  ]
})

const ativo = (para: string) =>
  para === '/painel' ? rota.path === '/painel' : rota.path.startsWith(para)
</script>
