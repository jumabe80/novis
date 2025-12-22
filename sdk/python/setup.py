from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="novis-sdk",
    version="1.0.0",
    author="NOVIS Protocol",
    author_email="dev@novisdefi.com",
    description="NOVIS SDK - Gasless payments for AI agents on Base",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/jumabe80/novis",
    project_urls={
        "Bug Tracker": "https://github.com/jumabe80/novis/issues",
        "Documentation": "https://novisdefi.com",
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    packages=find_packages(),
    python_requires=">=3.9",
    install_requires=[
        "web3>=6.0.0",
        "eth-account>=0.9.0",
    ],
    keywords="novis stablecoin base ethereum ai-agents gasless crypto defi",
)
