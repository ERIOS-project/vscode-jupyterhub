# VS Code JupyterHub Image

**VS Code JupyterHub** is a Docker image that integrates **code-server (VS Code in the browser)** within a **JupyterHub environment**, allowing secure, authenticated access to a full VS Code instance from the Jupyter interface using `jupyter-server-proxy`.

📌 **Main Features**

* 💻 Launch Visual Studio Code from JupyterHub via a secure proxy
* 🔐 Authentication handled entirely by JupyterHub
* ⚙️ Built on top of `jupyter/minimal-notebook` for speed and simplicity
* 🚀 Includes CI/CD via GitHub Actions for automated publishing to GHCR
* 🧰 Includes only essential developer tools: `debugpy`, `poetry`, `mamba`

---

🛠️ **Installation and Setup**

📥 **Prerequisites**

Make sure you have:

* Docker
* JupyterHub (configured separately)
* A GitHub account with access to GHCR (for pulling prebuilt images)

🚀 **Build Locally**

```bash
git clone https://github.com/your-org/vscode-jupyterhub-image.git
cd vscode-jupyterhub-image
docker build -t vscode-jupyterhub .
```

---

🐳 **Use with JupyterHub**

To run this image as a user container inside your JupyterHub setup:

```python
# In your jupyterhub_config.py
c.DockerSpawner.image = "ghcr.io/your-org/vscode-jupyterhub:latest"
```

After launching a notebook server, users will see a **“VS Code”** button in the Jupyter interface, thanks to `jupyter-server-proxy`.

---

⚙️ **CI/CD Pipeline**

This project includes a GitHub Actions workflow:

```
.github/workflows/docker-ghcr.yaml
```

It automates:

* Docker image build on push to `main`
* Image tagging and publishing to [GHCR](https://ghcr.io)

---

📂 **Project Structure**

```
vscode-jupyterhub-image/
│── .github/workflows/
│   └── docker-ghcr.yaml         # GitHub Actions CI/CD pipeline
│── Dockerfile                   # Builds Jupyter + code-server + proxy setup
│── README.md                    # Project documentation
```

---

📦 **Included Tools**

* `code-server` – Browser-based VS Code
* `jupyter-server-proxy` – For URL-based routing inside Jupyter
* `mamba` – Fast conda replacement
* `debugpy` – Debugging Python apps
* `poetry` – Python dependency management

---

👥 **Contributors**

Contributions are welcome!

* Fork this repository
* Create a feature branch: `feature/your-change`
* Open a pull request

---

🚀 Ready to bring a modern, secure development experience into your JupyterHub instance!

