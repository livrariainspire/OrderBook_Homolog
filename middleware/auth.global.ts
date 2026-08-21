const publicas = ['/', '/cadastro', '/recuperar', '/aguardando']

export default defineNuxtRouteMiddleware(async (para) => {
  if (!import.meta.client) return
  if (!configOk()) return

  const sessao = useSessao()
  if (!sessao.value.pronta) await carregarSessao()

  const logado = !!sessao.value.usuario
  const perfil = sessao.value.perfil
  const ehPublica = publicas.includes(para.path)

  if (!logado && !ehPublica) return navigateTo('/')

  if (logado && perfil && perfil.status !== 'aprovado' && para.path !== '/aguardando') {
    return navigateTo('/aguardando')
  }

  if (logado && perfil?.status === 'aprovado' && (para.path === '/' || para.path === '/cadastro')) {
    return navigateTo('/painel')
  }

  if (logado && perfil?.status === 'aprovado' && para.path.startsWith('/admin') && perfil.role !== 'admin') {
    return navigateTo('/painel')
  }

  // Igreja da Rede nao controla estoque nem registra venda
  const soPonto = ['/estoque', '/vendas', '/maquininha']
  if (logado && perfil?.role === 'igreja' && soPonto.some(r => para.path.startsWith(r))) {
    return navigateTo('/recebidos')
  }
  if (logado && perfil?.role !== 'igreja' && para.path === '/recebidos') {
    return navigateTo('/painel')
  }
})
