# ---------------------------------------------------------------------------
# Prod environment overrides.
# `image` is intentionally omitted – always supplied via the approval workflow
# with -var="image=<tag>" after explicit human sign-off.
# ---------------------------------------------------------------------------
replica_count = 2
ingress_host  = "helloworld.example.com"
ingress_class = "nginx"
kube_context  = "arn:aws:eks:us-east-1:123456789012:cluster/my-cluster"
