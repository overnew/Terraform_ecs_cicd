# reference with https://github.com/aws-samples/aws-codepipeline-terraform-cicd-samples

locals {
  codepipe_name = format("%s-%s",var.project_name ,"codepipeline")
  pipe_role_name = format("%s-%s",var.project_name ,"role")
  pipe_bucket_name = format("%s-%s",var.project_name ,"bucket-ldj")
}

terraform  {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "ap-northeast-1"
}


resource "aws_codepipeline" "codepipeline" {
  name     = local.codepipe_name
  role_arn = ${역할}

  artifact_store {
    location = ${파이프라인에서 사용할 버킷명}
    type     = "S3"
  }
  
  # 깃허브를 소스로 이용합니다.
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.this.arn
        FullRepositoryId = ${깃 레포지토리}
        BranchName       = ${브랜치}
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeCommit"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceOutput"]
      run_order        = 1

      configuration = {
        RepositoryName       = var.source_repository_name
        BranchName           = var.source_repository_branch
        PollForSourceChanges = "true"   #변경사항에 자동 반응해 build
      }
    }
  }


  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"] # 다음 스테이지로 넘길 아웃풋을 지정합니다.
      version          = "1"

      configuration = {
        ProjectName = var.build_name   # 생성할 코드빌드를 이용합니다.
      }
    }
  }

 # pipeLine에서 관리자가 직접 승인해주는 단계를 생성합니다
  stage {
    name = "Approve"
    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

 
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = { # 생성할 codeDeploy를 사용합니다.
        ApplicationName     = ${디플로이앱}
        DeploymentGroupName = ${디플로이그룹}
      }
    }
  }
}

# AWS CodeStar를 외부 서비스와 연결시켜주는 테라폼 리소스
resource "aws_codestarconnections_connection" "this" {
  name          = ${커넥션명}
  provider_type = "GitHub"
}

# iam
module "iam" {
  source                  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version                 = "~> 4.3"
  create_role             = true
  create_instance_profile = true
  role_name               = pipe_role_name
  role_requires_mfa       = false
  trusted_role_services = ["codepipeline.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AWSCodeStarFullAccess",
    "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess",
    "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess",
  ]
}

# s3 codePipeLine에서 사용할 버킷
module "s3_artifact" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  bucket        = local.pipe_bucket_name
  acl           = "private"
  force_destroy = true
  versioning    = { enabled = false }
}
