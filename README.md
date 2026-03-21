# Lab K8s Supervisor

Repositório de infraestrutura para o projeto **Tennessee Eastman Digital Twin Lab**.
Contém configurações de cluster, manifests de deploy e scripts de setup para rodar a planta TEP + operator supervisório em diferentes ambientes.

## Ambientes

| Diretório | Ambiente | Status |
|-----------|----------|--------|
| [`local/`](local/) | **Kind** (cluster local, sem cloud) | ativo |
| [`k8s-lab-1-aws/`](k8s-lab-1-aws/) | AWS (EC2 + Terraform) | legado |
| [`k8s-lab-1-azr/`](k8s-lab-1-azr/) | Azure | placeholder |
| [`k8s-lab-1-gcp/`](k8s-lab-1-gcp/) | GCP | placeholder |

## Lab Local (Kind)

O ambiente principal de desenvolvimento. Roda tudo no seu PC com Docker + Kind.

**Pré-requisitos:** Docker, Kind (v0.27+), kubectl.

```bash
cd local/
bash setup.sh
```

Detalhes completos em [`local/README.md`](local/README.md).

## Repositórios relacionados

| Repo | Descrição |
|------|-----------|
| [fork-tennesseeEastman](https://github.com/Green-Cinnamon-Labs/fork-tennesseeEastman) | Planta TEP (simulação Rust + gRPC) |
| [cluster-api-provider-plc](https://github.com/Green-Cinnamon-Labs/cluster-api-provider-plc) | Operator supervisório (Go + controller-runtime) |

## Nota

> O `.gitignore` ignora credenciais, chaves SSH, e artefatos do Terraform. É normal que esses arquivos não apareçam no repositório remoto.
