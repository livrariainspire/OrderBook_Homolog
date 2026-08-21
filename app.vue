<template>
  <div v-if="!pronto" class="tela-auth">
    <div class="cartao cartao-auth centro">
      <h2 style="font-size:18px;margin-bottom:10px">Configuração pendente</h2>
      <p style="color:var(--texto);font-size:14px;line-height:1.6">
        Abra o arquivo <strong>public/config.js</strong> no repositório e preencha o endereço
        e a chave do projeto Supabase.
      </p>
    </div>
  </div>
  <NuxtLayout v-else>
    <NuxtPage />
  </NuxtLayout>
</template>

<script setup lang="ts">
const pronto = ref(true)
onMounted(() => { pronto.value = configOk() })
</script>
