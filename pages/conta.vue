<template>
  <div>
    <div class="cabecalho"><div><h1>Minha conta</h1><p>Seus dados de contato e acesso.</p></div></div>

    <div v-if="msg" class="aviso" :class="erro ? 'aviso-erro' : 'aviso-ok'">{{ msg }}</div>

    <div class="painel">
      <div class="painel-topo"><h2>Dados pessoais</h2></div>
      <div class="painel-corpo">
        <div class="grade-2">
          <div class="grupo">
            <label class="rotulo">Nome completo</label>
            <input v-model="nome" class="campo" />
          </div>
          <div class="grupo">
            <label class="rotulo">WhatsApp</label>
            <input :value="zap" class="campo" inputmode="numeric" @input="e => zap = mascaraZap((e.target as HTMLInputElement).value)" />
          </div>
        </div>
        <div class="grupo">
          <label class="rotulo">E-mail</label>
          <input :value="perfil?.email" class="campo" disabled />
        </div>
        <div class="grupo">
          <label class="rotulo">Perfil</label>
          <input :value="rotuloPerfil(perfil?.role) + (unidade ? ' · ' + unidade.name : '')" class="campo" disabled />
        </div>
        <button class="btn btn-principal" style="width:auto" :disabled="ocupado" @click="salvar">Salvar alterações</button>
      </div>
    </div>

    <div class="painel">
      <div class="painel-topo"><h2>Trocar senha</h2></div>
      <div class="painel-corpo">
        <div class="grade-2">
          <div class="grupo">
            <label class="rotulo">Nova senha</label>
            <input v-model="senha" class="campo" type="password" minlength="8" placeholder="Mínimo 8 caracteres" />
          </div>
          <div class="grupo">
            <label class="rotulo">Repetir senha</label>
            <input v-model="senha2" class="campo" type="password" minlength="8" />
          </div>
        </div>
        <button class="btn btn-contorno" style="width:auto" :disabled="ocupado" @click="trocarSenha">Trocar senha</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'app' })

const supa = useSupa()
const sessao = useSessao()
const perfil = computed(() => sessao.value.perfil)
const unidade = computed(() => sessao.value.unidade)

const nome = ref(perfil.value?.full_name ?? '')
const zap = ref(mascaraZap(perfil.value?.whatsapp ?? ''))
const senha = ref(''); const senha2 = ref('')
const msg = ref(''); const erro = ref(false); const ocupado = ref(false)

async function salvar() {
  ocupado.value = true; msg.value = ''
  const { error } = await supa.from('profiles')
    .update({ full_name: nome.value.trim(), whatsapp: soDigitos(zap.value) })
    .eq('id', perfil.value!.id)
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? 'Não foi possível salvar: ' + error.message : 'Dados atualizados.'
  if (!error) await carregarSessao()
}

async function trocarSenha() {
  msg.value = ''
  if (senha.value.length < 8) { erro.value = true; msg.value = 'A senha precisa ter ao menos 8 caracteres.'; return }
  if (senha.value !== senha2.value) { erro.value = true; msg.value = 'As duas senhas precisam ser iguais.'; return }
  ocupado.value = true
  const { error } = await supa.auth.updateUser({ password: senha.value })
  ocupado.value = false
  erro.value = !!error
  msg.value = error ? 'Não foi possível trocar: ' + error.message : 'Senha alterada.'
  senha.value = ''; senha2.value = ''
}
</script>
