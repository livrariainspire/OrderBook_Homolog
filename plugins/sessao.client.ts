export default defineNuxtPlugin(async () => {
  if (!configOk()) return
  await carregarSessao()
  useSupa().auth.onAuthStateChange((evento) => {
    if (evento === 'SIGNED_OUT') {
      useSessao().value = { pronta: true, usuario: null, perfil: null, unidade: null }
    }
  })
})
