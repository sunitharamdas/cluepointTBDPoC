# ---------------------------------------------------------------------------
# Dev environment overrides.
# `image` is intentionally omitted – it is always supplied by the pipeline
# with -var="image=<tag>" to ensure the deployed version is traceable to a
# specific CI build. Do not hard-code an image tag here.
# ---------------------------------------------------------------------------
replica_count = 1
ingress_host  = "dev.helloworld.example.com"
ingress_class = "nginx"
kube_context  = "arn:aws:eks:us-east-1:123456789012:cluster/my-cluster"
