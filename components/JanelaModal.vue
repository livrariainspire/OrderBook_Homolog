<template>
  <div class="fundo-janela" @click.self="$emit('fechar')">
    <div class="janela" role="dialog" aria-modal="true">
      <div class="janela-topo">
        <h3>{{ titulo }}</h3>
        <button class="fechar" aria-label="Fechar" @click="$emit('fechar')">&times;</button>
      </div>
      <div class="janela-corpo"><slot /></div>
      <div class="janela-base"><slot name="acoes" /></div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ titulo: string }>()
defineEmits(['fechar'])
</script>
