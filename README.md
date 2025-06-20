# Gthulhu Documentation

This repository contains the official documentation for Gthulhu and SCX GoLand Core projects, built with MkDocs and Material theme.

## 🌐 Live Documentation

Visit the documentation at: [https://gthulhu.github.io/gthulhu-docs](https://gthulhu.github.io/gthulhu-docs)

## 📚 Documentation Structure

The documentation is available in both Chinese and English:

### Chinese (中文)
- [首頁](docs/index.md) - 專案概述和快速開始
- [安裝指南](docs/installation.md) - 詳細安裝步驟
- [工作原理](docs/how-it-works.md) - 核心工作原理與技術架構
- [專案目標](docs/project-goals.md) - 設計理念與發展目標
- [API 參考](docs/api-reference.md) - 完整 API 文檔
- [常見問題](docs/faq.md) - 常見問題與解答
- [貢獻指南](docs/contributing.md) - 開發者參與指南

### English
- [Home](docs/index.en.md) - Project overview and quick start
- [Installation](docs/installation.en.md) - Detailed installation steps
- [How It Works](docs/how-it-works.en.md) - Core working principles and architecture
- [Project Goals](docs/project-goals.en.md) - Design philosophy and development goals
- [API Reference](docs/api-reference.en.md) - Complete API documentation
- [FAQ](docs/faq.en.md) - Frequently asked questions
- [Contributing](docs/contributing.en.md) - Developer participation guide

## 🛠️ Local Development

### Prerequisites

- Python 3.7+
- pip

### Setup

1. Clone the repository:
```bash
git clone https://github.com/Gthulhu/gthulhu-docs.git
cd gthulhu-docs
```

2. Install dependencies:
```bash
pip install mkdocs mkdocs-material mkdocs-mermaid2-plugin
```

3. Start the development server:
```bash
mkdocs serve
```

4. Open your browser and visit http://127.0.0.1:8000

### Build Documentation

To build the static site:
```bash
mkdocs build
```

The built site will be in the `site/` directory.

## 🚀 Deployment

### Using the Deploy Script

We provide a convenient deployment script:

```bash
# Build documentation
./deploy.sh

# Build and serve locally
./deploy.sh --serve

# Build and deploy to GitHub Pages
./deploy.sh --deploy
```

### Manual Deployment

#### GitHub Pages

```bash
mkdocs gh-deploy
```

#### Other Platforms

1. Build the documentation:
```bash
mkdocs build
```

2. Upload the `site/` directory to your hosting provider.

## 📝 Contributing to Documentation

We welcome contributions to improve the documentation! Here's how:

1. **Fork** this repository
2. **Create** a new branch for your changes
3. **Edit** the Markdown files in the `docs/` directory
4. **Test** your changes locally with `mkdocs serve`
5. **Submit** a pull request

### Adding New Pages

1. Create a new Markdown file in the `docs/` directory
2. For bilingual support, create both `.md` (Chinese) and `.en.md` (English) versions
3. Add the new page to `mkdocs.yml` in the `nav` section

### Writing Guidelines

- Use clear, concise language
- Include code examples where appropriate
- Add diagrams using Mermaid syntax for complex concepts
- Ensure both Chinese and English versions are consistent
- Test all code examples before submitting

## 🔧 Configuration

The documentation is configured through `mkdocs.yml`. Key features enabled:

- **Material Theme**: Modern, responsive design
- **Bilingual Support**: Chinese and English content
- **Mermaid Diagrams**: Support for flowcharts and diagrams
- **Code Highlighting**: Syntax highlighting for multiple languages
- **Search**: Full-text search in both languages
- **Dark/Light Mode**: Theme switching

## 📄 License

This documentation is licensed under the same terms as the Gthulhu project - GNU General Public License version 2.

## 🤝 Support

If you have questions about the documentation:

- 📝 **Documentation Issues**: [GitHub Issues](https://github.com/Gthulhu/gthulhu-docs/issues)
- 💬 **General Questions**: [GitHub Discussions](https://github.com/Gthulhu/Gthulhu/discussions)
- 🐛 **Project Issues**: [Gthulhu Issues](https://github.com/Gthulhu/Gthulhu/issues)

---

Made with ❤️ by the Gthulhu community
