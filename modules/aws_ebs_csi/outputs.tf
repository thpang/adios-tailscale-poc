# Copyright © 2021-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "iam_assumable_role_with_oidc" {
  description = "ARN of IAM role for ebs-csi-controller Service Account."
  value       = module.iam_assumable_role_with_oidc
}
