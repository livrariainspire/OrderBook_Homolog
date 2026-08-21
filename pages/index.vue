<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth">
      <MarcaInspire />
      <hr class="divisor" />

      <h1 style="font-size:26px">Entrar</h1>
      <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
        Use o e-mail e a senha cadastrados pela administração.
      </p>

      <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>

      <form @submit.prevent="entrar">
        <div class="grupo">
          <label class="rotulo" for="email">E-mail</label>
          <input id="email" v-model="email" class="campo" type="email" required
                 autocomplete="email" placeholder="nome@livrariainspire.com.br" />
        </div>
        <div class="grupo">
          <label class="rotulo" for="senha">Senha</label>
          <input id="senha" v-model="senha" class="campo" type="password" required
                 autocomplete="current-password" placeholder="Sua senha" />
        </div>
        <button class="btn btn-principal" :disabled="ocupado" style="margin-top:6px">
          {{ ocupado ? 'Entrando...' : 'Entrar' }}
        </button>
      </form>

      <div class="linha-acoes" style="justify-content:center;margin-top:18px;gap:22px">
        <NuxtLink to="/recuperar" class="btn-linha">Esqueci minha senha</NuxtLink>
        <NuxtLink to="/cadastro" class="btn-linha">Criar minha conta</NuxtLink>
      </div>

      <p class="pe-auth">
        Problemas para entrar? Fale com a administração da Livraria Inspire.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })

const email = ref('')
const senha = ref('')
const erro = ref('')
const ocupado = ref(false)

async function entrar() {
  erro.value = ''
  ocupado.value = true
  const { error } = await useSupa().auth.signInWithPassword({
    email: email.value.trim(), password: senha.value
  })
  if (error) {
    erro.value = error.message.includes('Invalid')
      ? 'E-mail ou senha incorretos.'
      : 'Não foi possível entrar: ' + error.message
    ocupado.value = false
    return
  }
  const s = await carregarSessao()
  await navigateTo(s.perfil?.status === 'aprovado' ? '/painel' : '/aguardando')
}
</script>
