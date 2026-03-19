import { defineConfig } from "vitepress";

export default defineConfig({
  title: "Agentic Executables",
  description:
    "Docs-first onboarding and reference for humans and AI agents.",
  lastUpdated: true,
  appearance: true,
  cleanUrls: true,
  markdown: {
    lineNumbers: true,
  },
  themeConfig: {
    outline: {
      label: "On this page",
      level: "deep",
    },
    returnToTopLabel: "Back to top",
    sidebarMenuLabel: "Guide",
    darkModeSwitchLabel: "Theme",
    search: {
      provider: "local",
    },
    nav: [
      {
        text: "Start",
        items: [
          { text: "Overview", link: "/overview/" },
          { text: "Get Started", link: "/get-started/" },
          { text: "Install", link: "/install/" },
        ],
      },
      {
        text: "Workflows",
        items: [
          { text: "Use", link: "/use/" },
          { text: "Know", link: "/know/" },
          { text: "Hub", link: "/hub/" },
        ],
      },
      {
        text: "Build",
        items: [
          { text: "Develop", link: "/develop/" },
          { text: "MCP", link: "/mcp/" },
        ],
      },
      { text: "Troubleshooting", link: "/troubleshooting/" },
      { text: "Reference", link: "/reference/" },
    ],
    sidebar: {
      "/overview/": [
        {
          text: "Introduction",
          items: [{ text: "What is Agentic Executables", link: "/overview/" }],
        },
      ],
      "/get-started/": [
        {
          text: "First 10 minutes",
          items: [
            { text: "Choose your path", link: "/get-started/" },
            { text: "Beginner track", link: "/get-started/beginner" },
            { text: "Developer track", link: "/get-started/developer" },
            { text: "Agent track", link: "/get-started/agent" },
          ],
        },
      ],
      "/install/": [
        {
          text: "Install",
          items: [{ text: "Install and verify", link: "/install/" }],
        },
      ],
      "/hub/": [
        {
          text: "Operations",
          items: [{ text: "Local-first hub", link: "/hub/" }],
        },
      ],
      "/know/": [
        {
          text: "Operations",
          items: [{ text: "Knowledge extraction", link: "/know/" }],
        },
      ],
      "/use/": [
        {
          text: "Operations",
          items: [{ text: "First workflows", link: "/use/" }],
        },
      ],
      "/develop/": [
        {
          text: "Develop",
          items: [{ text: "Architecture and extension", link: "/develop/" }],
        },
      ],
      "/mcp/": [
        {
          text: "MCP",
          items: [{ text: "MCP integration", link: "/mcp/" }],
        },
      ],
      "/troubleshooting/": [
        {
          text: "Troubleshooting",
          items: [{ text: "Recover quickly", link: "/troubleshooting/" }],
        },
      ],
      "/reference/": [
        {
          text: "Reference",
          items: [
            { text: "Overview", link: "/reference/" },
            { text: "IA and UX strategy", link: "/reference/ia-ux-strategy" },
            { text: "Metrics baseline", link: "/reference/metrics" },
            { text: "Agent page contract", link: "/reference/agent-contract" },
            { text: "Ownership and governance", link: "/reference/governance" },
            { text: "Acknowledgments", link: "/reference/acknowledgments" },
          ],
        },
      ],
    },
    socialLinks: [
      {
        icon: "github",
        link: "https://github.com/fluent-meaning-symbiotic/agentic_executables",
      },
    ],
    footer: {
      message: "Extract once, execute everywhere.",
      copyright:
        "Copyright © Agentic Executables contributors",
    },
  },
});
