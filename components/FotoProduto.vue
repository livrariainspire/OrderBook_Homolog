<template>
  <img v-if="url" :src="url" class="produto-foto" :alt="titulo" />
  <div v-else class="produto-foto produto-foto-vazia">
    {{ tipo === 'livro' ? '\u{1F4D6}' : '\u{1F381}' }}
  </div>
</template>

<script setup lang="ts">
defineProps<{ url?: string | null; titulo?: string; tipo?: string }>()
</script>
