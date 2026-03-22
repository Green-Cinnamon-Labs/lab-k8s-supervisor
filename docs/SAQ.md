# Short Answer Questions

## O que é o `kind`?

O `Kind` (Kubernetes in Docker) não é o `control-plane`, ele só te dá um cluster Kubernetes descartável (o bootstrap cluster). Dentro dele você instala os controladores do Cluster API (CAPI). Esses controladores, sim, vão orquestrar a criação de um novo control-plane real (com etcd, kube-apiserver, etc.) nos nós que você indicar.

Então: Kind = bootstrap cluster; nele roda o CAPI; o CAPI cria e gerencia o control-plane e os workers "de verdade".

No contexto do lab TEP, o Kind serve como cluster local onde o operator supervisório roda como Pod.


## O que é o `clusterctl`?

O clusterctl é um CLI oficial do Cluster API. Ele serve para inicializar o CAPI dentro de um cluster de bootstrap (ex: Kind), além de gerar manifestos e gerenciar upgrades dos componentes do CAPI.


## O que acontece quando você reinicia a instancia EC2?

É muito o EC2 trocar o IP interno da máquina. Oque acontece? a instancia é trocada? a infra é outra? o EC2 drena? Zonas de disponibilidade.

Após ter configurado a máquina eu a reinicializei. Com os comandos abaixo constatei que estava tudo em pé:

![Container 'Kind' no ar após reiniciar](image/image1.png)


## Porque `k8s` é melhor que `IaC` convencional?

Agora, por que isso seria diferente de um IaC tradicional (Terraform/CloudFormation)?

1) Reconciliação contínua, não ação pontual

- No Kubernetes, um controlador fica rodando em loop infinito garantindo que o estado real combine com o estado desejado que você declarou.
- Se alguém apagar um load balancer criado via CRD, o controlador recria.
- Se mudar uma subnet sem querer, ele corrige.
- IaC tradicional (Terraform/CloudFormation) só age quando você manda.
- Se o estado muda depois, paciência.

2) Tudo vira parte do ecossistema do cluster

Com CRDs, recursos de infraestrutura entram no mesmo fluxo do Kubernetes:
- RBAC, eventos, anotação, logs, conditions, kubectl describe, tudo.
- É um modelo unificado.
- IaC vive fora do cluster, com outro conjunto de ferramentas e outro ciclo de vida.

3) Integração com automação nativa do Kubernetes

- Controllers usam o mesmo motor de reconciliação de Deployments, Ingress, Services, etc.
- O cluster reage automaticamente a mudanças, falhas e atualizações.
- IaC não reage — ele só aplica. Qualquer reação precisa ser programada fora.


## Porque eu iria querer transformar máquinas em providers?

1) Reaproveitar máquina ociosa → Se a empresa tem desktop parado, servidor velho ou laboratório subutilizado, você transforma tudo isso em "nós" baratos para clusters provisórios.

2) Testar cenários híbridos → Você consegue criar clusters que misturam AWS com hardware local, simulando edge, filiais, chão de fábrica e ambientes restritos.

3) Padronizar o ciclo de vida de máquinas internas → Com CAPI + provider local, qualquer máquina vira "infra declarada": nasce, morre, atualiza e escala a partir de YAML, igual nuvem.

4) Garantir reconciliação contínua → Se um PC falha, formata, troca de disco ou reinicia, o CAPI simplesmente recria a máquina ou reconfigura ela. Mano, isso é ouro em ambiente físico.

5) Treinar times sem pagar nuvem → Você cria clusters inteiros para ensino, CI, experimentos e PoCs sem gastar um centavo com EC2, EKS e VPC.


## Por que o operator roda dentro do Kind e não como container separado?

Existem dois tipos de Pod conceitualmente:

Pods que o Kubernetes mantém — são as aplicações. Um servidor web, uma API, um banco de dados. O Kubernetes garante que estão rodando, reinicia se caírem, escala se precisar. O Kubernetes não sabe o que eles fazem, só mantém eles vivos.

Pods que estendem o Kubernetes — são os operators/controllers. Eles rodam como Pod, mas o propósito deles é dar capacidades novas ao Kubernetes. O CAPA é um Pod que ensina o Kubernetes a criar EC2 na AWS. O seu operator é um Pod que ensina o Kubernetes a supervisionar uma planta industrial. Sem eles, o Kubernetes não sabe o que é uma Machine na AWS nem o que é um PLCMachine.

O seu operator é do segundo tipo. Ele é uma extensão do Kubernetes — é como se você estivesse instalando um "plugin" que dá ao cluster a capacidade de entender e supervisionar a planta TEP. Ele roda como Pod porque é assim que extensões são deployadas no Kubernetes, mas ele não é uma aplicação que o Kubernetes "mantém no ar" — ele é parte do próprio Kubernetes expandido.

Porque o Kubernetes só gerencia o que roda dentro dele. Ele não sabe que existem containers Docker avulsos na máquina.

O operator precisa ler e escrever recursos PLCMachine no cluster (buscar spec, atualizar status). Rodando como Pod, ele faz isso nativamente via controller-runtime, usando o ServiceAccount e o RBAC do cluster. O Kubernetes garante que o operator está rodando, reinicia se cair, e pode escalar se necessário.

Se rodasse fora, seria um script Go solto sem nenhuma orquestração.


## Por que tem container dentro de container?

Isso é específico do Kind (ambiente local). O Kind simula um nó Kubernetes dentro de um container Docker. Dentro desse nó, o Kubernetes usa containerd pra rodar Pods. Então sim, o operator é um container dentro de um container.

Em produção, o nó seria uma VM real (ou bare metal). O Kubernetes rodaria direto nessa VM e não haveria aninhação. O "container dentro de container" é o custo de simular um cluster inteiro na sua máquina — e só existe no ambiente de desenvolvimento.


## A planta roda no Kubernetes?

Não. A planta está fora do Kubernetes. Ela é um container Docker standalone na sua máquina.

Se ela estivesse dentro do Kind como Pod, aí sim seria um Pod do primeiro tipo — uma aplicação que o Kubernetes mantém rodando.

No seu caso a planta é um sistema externo, como a AWS é pro CAPA. O CAPA não roda a AWS dentro do Kubernetes — ele se conecta nela. O seu operator não roda a planta dentro do Kubernetes — ele se conecta nela via gRPC.

Não. A planta é um sistema externo. Roda como container Docker standalone fora do cluster, expondo gRPC na porta 50051.

O operator dentro do Kubernetes se conecta nela via gRPC. Num cenário real, a planta seria um PLC físico, uma simulação em outro servidor, ou qualquer sistema industrial que expõe dados.

O Kubernetes não gerencia a planta — ele só gerencia o operator que a observa.


## O que é o `kind load docker-image`?

Copia uma imagem Docker da máquina local pra dentro do nó Kind. São ambientes isolados — o Docker Desktop e o containerd dentro do Kind não compartilham imagens.

Sem esse comando, o Kubernetes tentaria puxar a imagem de um registry remoto (Docker Hub, por exemplo) e falharia, porque `plc-operator:latest` só existe localmente.


## O Kubernetes usa o Docker da minha máquina pra subir containers?

Não. O Kubernetes tem seu próprio runtime de containers (containerd) dentro dos nós. Ele não sabe que o Docker Desktop existe na sua máquina.

Quando você faz `docker build`, a imagem fica no Docker Desktop. Quando o Kubernetes precisa rodar um Pod, ele pede pro containerd (dentro do nó). São dois mundos separados. Por isso as imagens precisam ser carregadas explicitamente no Kind com `kind load docker-image`.