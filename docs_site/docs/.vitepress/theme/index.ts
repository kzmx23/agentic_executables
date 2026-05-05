import DefaultTheme from "vitepress/theme";
import AeLayout from "./AeLayout.vue";
import "./custom.css";

export default {
  extends: DefaultTheme,
  Layout: AeLayout,
};
