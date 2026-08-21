<template>
  <div class="tela-auth">
    <div class="cartao cartao-auth">
      <MarcaInspire />
      <hr class="divisor" />

      <!-- ETAPA 1: dados -->
      <template v-if="etapa === 'dados'">
        <h1 style="font-size:26px">Criar minha conta</h1>
        <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
          Preencha seus dados. Enviaremos um código para o seu e-mail confirmar que ele é seu.
        </p>

        <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>

        <form @submit.prevent="cadastrar">
          <div class="grupo">
            <label class="rotulo">Nome completo</label>
            <input v-model="nome" class="campo" required placeholder="Seu nome e sobrenome" />
          </div>
          <div class="grupo">
            <label class="rotulo">E-mail</label>
            <input v-model="email" class="campo" type="email" required placeholder="nome@exemplo.com.br" />
          </div>
          <div class="grupo">
            <label class="rotulo">WhatsApp</label>
            <input :value="zap" class="campo" required inputmode="numeric"
                   placeholder="(11) 90000-0000" @input="digitarZap" />
          </div>
          <div class="grade-2">
            <div class="grupo">
              <label class="rotulo">Senha</label>
              <input v-model="senha" class="campo" type="password" required minlength="8" placeholder="Mínimo 8 caracteres" />
            </div>
            <div class="grupo">
              <label class="rotulo">Repetir senha</label>
              <input v-model="senha2" class="campo" type="password" required minlength="8" placeholder="Digite de novo" />
            </div>
          </div>
          <button class="btn btn-principal" :disabled="ocupado" style="margin-top:6px">
            {{ ocupado ? 'Enviando código...' : 'Enviar código por e-mail' }}
          </button>
        </form>

        <div class="centro" style="margin-top:18px">
          <NuxtLink to="/" class="btn-linha">Já tenho conta</NuxtLink>
        </div>
      </template>

      <!-- ETAPA 2: codigo -->
      <template v-else-if="etapa === 'codigo'">
        <h1 style="font-size:24px">Confirmar o e-mail</h1>
        <p style="color:var(--texto);font-size:14px;margin:8px 0 22px;line-height:1.5">
          Enviamos um código de 6 digitos para <strong>{{ email }}</strong>.
          Digite abaixo para concluir o cadastro.
        </p>

        <div v-if="erro" class="aviso aviso-erro">{{ erro }}</div>
        <div v-if="reenviado" class="aviso aviso-ok">Código reenviado. Confira sua caixa de entrada.</div>

        <form @submit.prevent="validar">
          <div class="grupo">
            <label class="rotulo" for="codigo">Código recebido</label>
            <input id="codigo" ref="campoCodigo" :value="codigo" class="campo codigo"
                   inputmode="numeric" autocomplete="one-time-code" maxlength="6"
                   placeholder="000000" @input="digitarCodigo" />
          </div>
          <button class="btn btn-principal" :disabled="ocupado || codigo.length < 6">
            {{ ocupado ? 'Validando...' : 'Confirmar e-mail' }}
          </button>
        </form>

        <div class="linha-acoes" style="justify-content:center;margin-top:18px;gap:22px">
          <button class="btn-linha" :disabled="espera > 0 || ocupado" @click="reenviar">
            {{ espera > 0 ? `Reenviar em ${espera}s` : 'Reenviar código' }}
          </button>
          <button class="btn-linha" @click="voltar">Corrigir o e-mail</button>
        </div>

        <p class="pe-auth">
          Não encontrou? Procure na caixa de spam antes de pedir outro código.
        </p>
      </template>

      <!-- ETAPA 3: pronto -->
      <template v-else>
        <div class="centro">
          <div style="font-size:40px;line-height:1">&#9989;</div>
          <h1 style="font-size:23px;margin-top:14px">E-mail confirmado</h1>
          <p style="color:var(--texto);font-size:14px;margin:12px 0 22px;line-height:1.6">
            Seu cadastro foi enviado. A administração vai revisar seus dados, liberar o acesso
            e vincular você a sua filial. Você receberá o aviso pelo WhatsApp informado.
          </p>
          <NuxtLink to="/" class="btn btn-principal">Voltar para o início</NuxtLink>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'default' })

const etapa = ref<'dados' | 'codigo' | 'pronto'>('dados')
const nome = ref(''); const email = ref(''); const zap = ref('')
const senha = ref(''); const senha2 = ref('')
const codigo = ref('')
const erro = ref(''); const ocupado = ref(false); const reenviado = ref(false)
const espera = ref(0)
const campoCodigo = ref<HTMLInputElement | null>(null)
let relogio: any = null

function digitarZap(e: Event) { zap.value = mascaraZap((e.target as HTMLInputElement).value) }
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

async function cadastrar() {
  erro.value = ''
  if (senha.value !== senha2.value) { erro.value = 'As duas senhas precisam ser iguais.'; return }
  if (soDigitos(zap.value).length < 10) { erro.value = 'Informe o WhatsApp com DDD.'; return }

  ocupado.value = true
  try {
    await chamarApi('/cadastro/codigo', { email: email.value.trim() })
    etapa.value = 'codigo'
    codigo.value = ''
    contar()
    await nextTick()
    campoCodigo.value?.focus()
  } catch (e: any) {
    erro.value = e.message
  } finally {
    ocupado.value = false
  }
}

async function validar() {
  erro.value = ''; reenviado.value = false; ocupado.value = true
  try {
    await chamarApi('/cadastro/confirmar', {
      email: email.value.trim(),
      code: codigo.value,
      full_name: nome.value.trim(),
      whatsapp: soDigitos(zap.value),
      password: senha.value
    })
    etapa.value = 'pronto'
  } catch (e: any) {
    erro.value = e.message
  } finally {
    ocupado.value = false
  }
}

async function reenviar() {
  erro.value = ''; reenviado.value = false; ocupado.value = true
  try {
    await chamarApi('/cadastro/codigo', { email: email.value.trim() })
    reenviado.value = true
    contar()
  } catch (e: any) {
    erro.value = e.message
  } finally {
    ocupado.value = false
  }
}

function voltar() { etapa.value = 'dados'; erro.value = ''; codigo.value = '' }
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
