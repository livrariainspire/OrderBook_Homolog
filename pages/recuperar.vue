<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth">
      <MarcaInspire />
      <hr class="divisor" />

      <!-- ETAPA 1: e-mail -->
      <template v-if="etapa === 'email'">
        <h1 style="font-size:24px">Recuperar senha</h1>
        <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
          Informe seu e-mail. Enviaremos um código de 6 digitos para você criar uma nova senha.
        </p>

        <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>

        <form @submit.prevent="pedirCodigo">
          <div class="grupo">
            <label class="rotulo">E-mail</label>
            <input v-model="email" class="campo" type="email" required placeholder="nome@exemplo.com.br" />
          </div>
          <button class="btn btn-principal" :disabled="ocupado">
            {{ ocupado ? 'Enviando...' : 'Enviar código' }}
          </button>
        </form>

        <div class="centro" style="margin-top:18px">
          <NuxtLink to="/" class="btn-linha">Voltar para o início</NuxtLink>
        </div>
      </template>

      <!-- ETAPA 2: codigo e nova senha -->
      <template v-else-if="etapa === 'codigo'">
        <h1 style="font-size:24px">Criar nova senha</h1>
        <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
          Se existe uma conta com <strong>{{ email }}</strong>, o código chegou por e-mail.
          Digite o código e escolha a nova senha.
        </p>

        <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
        <div v-if="reenviado" class="aviso aviso-ok">Código reenviado. Confira sua caixa de entrada.</div>

        <form @submit.prevent="redefinir">
          <div class="grupo">
            <label class="rotulo" for="codigo">Código recebido</label>
            <input id="codigo" ref="campoCodigo" :value="codigo" class="campo codigo"
                   inputmode="numeric" autocomplete="one-time-code" maxlength="6"
                   placeholder="000000" @input="digitarCodigo" />
          </div>
          <div class="grade-2">
            <div class="grupo">
              <label class="rotulo">Nova senha</label>
              <input v-model="senha" class="campo" type="password" minlength="8" required placeholder="Mínimo 8 caracteres" />
            </div>
            <div class="grupo">
              <label class="rotulo">Repetir senha</label>
              <input v-model="senha2" class="campo" type="password" minlength="8" required />
            </div>
          </div>
          <button class="btn btn-principal" :disabled="ocupado || codigo.length < 6">
            {{ ocupado ? 'Salvando...' : 'Salvar nova senha' }}
          </button>
        </form>

        <div class="linha-acoes" style="justify-content:center;margin-top:18px;gap:22px">
          <button class="btn-linha" :disabled="espera > 0 || ocupado" @click="pedirCodigo">
            {{ espera > 0 ? `Reenviar em ${espera}s` : 'Reenviar código' }}
          </button>
          <button class="btn-linha" @click="etapa = 'email'">Corrigir o e-mail</button>
        </div>

        <p class="pe-auth">Não encontrou? Procure na caixa de spam antes de pedir outro código.</p>
      </template>

      <!-- ETAPA 3: pronto -->
      <template v-else>
        <div class="centro">
          <div style="font-size:40px;line-height:1">&#9989;</div>
          <h1 style="font-size:23px;margin-top:14px">Senha alterada</h1>
          <p style="color:var(--texto);font-size:14px;margin:12px 0 22px;line-height:1.6">
            Sua nova senha já está valendo. Entre com ela para continuar.
          </p>
          <NuxtLink to="/" class="btn btn-principal">Ir para a tela de entrada</NuxtLink>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })

const etapa = ref<'email' | 'codigo' | 'pronto'>('email')
const email = ref(''); const codigo = ref('')
const senha = ref(''); const senha2 = ref('')
const erro = ref(''); const ocupado = ref(false); const reenviado = ref(false)
const espera = ref(0)
const campoCodigo = ref<HTMLInputElement | null>(null)
let relogio: any = null

function digitarCodigo(e: Event) {
  codigo.value = (e.target as HTMLInputElement).value.replace(/\D/g, '').slice(0, 6)
  ;(e.target as HTMLInputElement).value = codigo.value
}

function contar() {
  espera.value = 60
  clearInterval(relogio)
  relogio = setInterval(() => { if (--espera.value <= 0) clearInterval(relogio) }, 1000)
}
onUnmounted(() => clearInterval(relogio))

async function pedirCodigo() {
  erro.value = ''; reenviado.value = false; ocupado.value = true
  try {
    await chamarApi('/senha/codigo', { email: email.value.trim() })
    if (etapa.value === 'codigo') reenviado.value = true
    etapa.value = 'codigo'
    contar()
    await nextTick()
    campoCodigo.value?.focus()
  } catch (e: any) {
    erro.value = e.message
  } finally {
    ocupado.value = false
  }
}

async function redefinir() {
  erro.value = ''; reenviado.value = false
  if (senha.value !== senha2.value) { erro.value = 'As duas senhas precisam ser iguais.'; return }
  ocupado.value = true
  try {
    await chamarApi('/senha/redefinir', {
      email: email.value.trim(), code: codigo.value, password: senha.value
    })
    etapa.value = 'pronto'
  } catch (e: any) {
    erro.value = e.message
  } finally {
    ocupado.value = false
  }
}
</script>

<style scoped>
.codigo {
  text-align: center;
  font-size: 30px;
  font-weight: 600;
  letter-spacing: .38em;
  text-indent: .38em;
  padding: 16px 12px;
  font-variant-numeric: tabular-nums;
}
</style>
