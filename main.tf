# DATA SOURCES

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# CLOUDWATCH LOG GROUPS

resource "aws_cloudwatch_log_group" "application" {
  name              = "/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "dataplane" {
  name              = "/eks/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "host" {
  name              = "/eks/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM POLICY — FLUENT BIT

resource "aws_iam_policy" "fluent_bit" {
  name = "${var.cluster_name}-fluent-bit-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# IAM ROLE — FLUENT BIT (IRSA)

data "aws_iam_policy_document" "fluent_bit_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:fluent-bit"]
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${var.cluster_name}-fluent-bit-role"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  role       = aws_iam_role.fluent_bit.name
  policy_arn = aws_iam_policy.fluent_bit.arn
}

# HELM RELEASE — FLUENT BIT

resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = var.namespace
  version    = "0.46.7"

  create_namespace = true

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.fluent_bit.arn
  }

  set {
    name  = "config.outputs"
    value = <<-EOT
      [OUTPUT]
          Name              cloudwatch_logs
          Match             kube.*
          region            ${data.aws_region.current.name}
          log_group_name    /eks/${var.cluster_name}/application
          log_stream_prefix from-fluent-bit-
          auto_create_group false

      [OUTPUT]
          Name              cloudwatch_logs
          Match             host.*
          region            ${data.aws_region.current.name}
          log_group_name    /eks/${var.cluster_name}/host
          log_stream_prefix from-fluent-bit-
          auto_create_group false
    EOT
  }

  set {
    name  = "config.filters"
    value = <<-EOT
      [FILTER]
          Name                kubernetes
          Match               kube.*
          Merge_Log           On
          Keep_Log            Off
          K8S-Logging.Parser  On
          K8S-Logging.Exclude On
    EOT
  }

  depends_on = [
    aws_iam_role_policy_attachment.fluent_bit,
    aws_cloudwatch_log_group.application,
    aws_cloudwatch_log_group.host
  ]
}