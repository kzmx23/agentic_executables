<script setup lang="ts">
import DefaultTheme from "vitepress/theme";

const Layout = DefaultTheme.Layout;
</script>

<template>
  <Layout>
    <template #home-features-after>
      <nav class="ae-machine-strip" aria-label="Machine-readable docs">
        <a href="/llms.txt">llms.txt</a>
        <span class="ae-machine-sep" aria-hidden="true">·</span>
        <a href="/llms-full.txt">llms-full.txt</a>
        <span class="ae-machine-sep" aria-hidden="true">·</span>
        <a href="/reference/agent-contract">Agent contract</a>
      </nav>
    </template>
  </Layout>
</template>
