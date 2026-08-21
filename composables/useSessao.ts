export type Perfil = {
  id: string
  full_name: string
  email: string
  whatsapp: string
  role: 'admin' | 'atendente' | 'igreja' | 'ponto' | null
  unit_id: string | null
  status: 'pendente' | 'aprovado' | 'rejeitado' | 'inativo'
}

export const useSessao = () => useState<{
  pronta: boolean
  usuario: any | null
  perfil: Perfil | null
  unidade: any | null
}>('sessao', () => ({ pronta: false, usuario: null, perfil: null, unidade: null }))

export async function carregarSessao() {
  const sessao = useSessao()
  const supa = useSupa()
  const { data: { user } } = await supa.auth.getUser()

  if (!user) {
    sessao.value = { pronta: true, usuario: null, perfil: null, unidade: null }
    return sessao.value
  }

  const { data: perfil } = await supa.from('profiles').select('*').eq('id', user.id).maybeSingle()
  let unidade = null
  if (perfil?.unit_id) {
    const { data } = await supa.from('units').select('*').eq('id', perfil.unit_id).maybeSingle()
    unidade = data
  }
  sessao.value = { pronta: true, usuario: user, perfil: perfil as any, unidade }
  return sessao.value
}

export async function sair() {
  await useSupa().auth.signOut()
  const sessao = useSessao()
  sessao.value = { pronta: true, usuario: null, perfil: null, unidade: null }
  await navigateTo('/')
}

export const rotuloPerfil = (r?: string | null) => ({
  admin: 'Administração',
  atendente: 'Atendimento',
  igreja: 'Igreja da Rede',
  ponto: 'Ponto de Partida'
}[r ?? ''] ?? 'Sem perfil')
