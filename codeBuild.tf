# iam
module "iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4.3"

  create_role             = true
  create_instance_profile = true
  role_name               = "codebuild-role"
  role_requires_mfa       = false

  trusted_role_services = ["codebuild.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
  
}

# codebuild
resource "aws_codebuild_project" "this" {
    depends_on = [ aws_codecommit_repository.source_repository ]
  name          = var.build_name  #"${var.project_name}-build"
  #build_timeout = ${타임아웃시간}
  service_role  = module.iam.iam_role_arn
  
  source {
    type      = "CODECOMMIT" #or S3, GITHUB 

    #소스파일 위치
    location  = "https://git-codecommit.${var.region}.amazonaws.com/v1/repos/${var.source_repository_name}"
    
    # 빌드 스펙의 위치 기본적으로 CodeBuild는 소스 코드 루트 디렉터리에서 buildspec.yml 파일을 찾습니다.
    # ${빌드 스펙 위치}
    #buildspec = 
  }

  #온디맨드 형식의 타입을 사용
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

  # vpc 설정
  vpc_config {
    vpc_id             = "" #aws_vpc.default.id #local.vpc_id 
    subnets            = ["subnet-02c59928b96231787"]
    security_group_ids = ["sg-0a1d1942a88d9d60e"]
  }

  # codePipeLine을 사용하기에 따로 codeBuild용 아티팩트 버킷을 사용하지않습니다.
  artifacts {
    type = "NO_ARTIFACTS"
  }

}

#data "aws_vpc" "default" {
#  default = true
#} 