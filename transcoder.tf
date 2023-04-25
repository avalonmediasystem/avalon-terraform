resource "aws_sns_topic" "this_transcode_notification" {
  name = "${local.namespace}-pipeline-topic"
}

data "aws_iam_policy_document" "transcoder" {
  statement {
    sid     = ""
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elastictranscoder.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "this_pipeline_role" {
  name               = "${local.namespace}-pipeline-role"
  assume_role_policy = data.aws_iam_policy_document.transcoder.json
}

data "aws_iam_policy_document" "this_pipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:Put*",
      "s3:ListBucket",
      "s3:*MultipartUpload*",
      "s3:Get*",
    ]

    resources = [
      aws_s3_bucket.this_masterfiles.arn,
      aws_s3_bucket.this_derivatives.arn,
      "${aws_s3_bucket.this_masterfiles.arn}/*",
      "${aws_s3_bucket.this_derivatives.arn}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this_transcode_notification.arn]
  }

  statement {
    effect = "Deny"

    actions = [
      "s3:*Delete*",
      "s3:*Policy*",
      "sns:*Remove*",
      "sns:*Delete*",
      "sns:*Permission*",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "this_pipeline_policy" {
  name   = "${local.namespace}-${var.app_name}-pipeline-policy"
  policy = data.aws_iam_policy_document.this_pipeline_policy.json
}

resource "aws_iam_role_policy_attachment" "this_pipeline" {
  role       = aws_iam_role.this_pipeline_role.name
  policy_arn = aws_iam_policy.this_pipeline_policy.arn
}

resource "aws_elastictranscoder_pipeline" "this_pipeline" {
  name          = "${local.namespace}-${var.app_name}-transcoding-pipeline"
  input_bucket  = aws_s3_bucket.this_masterfiles.id
  output_bucket = aws_s3_bucket.this_derivatives.id
  role          = aws_iam_role.this_pipeline_role.arn

  notifications {
    completed   = aws_sns_topic.this_transcode_notification.arn
    error       = aws_sns_topic.this_transcode_notification.arn
    progressing = aws_sns_topic.this_transcode_notification.arn
    warning     = aws_sns_topic.this_transcode_notification.arn
  }
}

locals {
  containers = [
    { container = "ts", description = "hls" },
    { container = "mp4", description = "mp4" }
  ]

  audio_qualities = [
    { quality = "high",   audio_bit_rate = "320" },
    { quality = "medium", audio_bit_rate = "128" }
  ]

  audio_presets = [
    for config in setproduct(local.audio_qualities, local.containers) : {
      container = config[1].container
      name = "${local.namespace}-audio-${config[0].quality}-${config[1].description}"
      description = "Avalon Media System: video/${config[0].quality}/${config[1].description}"
      audio_bit_rate = config[0].audio_bit_rate
    }
  ]

  video_qualities = [
    { quality = "high",   audio_bit_rate = "192", video_bit_rate = "2048", max_width = "1920", max_height = "1080" },
    { quality = "medium", audio_bit_rate = "128", video_bit_rate = "1024", max_width = "1280", max_height =  "720" },
    { quality = "low",    audio_bit_rate = "128", video_bit_rate =  "500", max_width =  "720", max_height =  "480" }
  ]

  video_presets = [
    for config in setproduct(local.video_qualities, local.containers) : {
      container = config[1].container
      name = "${local.namespace}-video-${config[0].quality}-${config[1].description}"
      description = "Avalon Media System: video/${config[0].quality}/${config[1].description}"
      audio_bit_rate = config[0].audio_bit_rate
      video_bit_rate = config[0].video_bit_rate
      max_width = config[0].max_width
      max_height = config[0].max_height
    }
  ]
}

resource "aws_elastictranscoder_preset" "this_preset_audio" {
  for_each    = { for preset in local.audio_presets : preset.name => preset }
  container   = each.value.container
  description = each.value.description
  name        = each.key

  audio {
    audio_packing_mode = "SingleTrack"
    bit_rate           = each.value.audio_bit_rate
    channels           = 2
    codec              = "AAC"
    sample_rate        = 44100
  }

  audio_codec_options {
    profile = "AAC-LC"
  }
}

resource "aws_elastictranscoder_preset" "this_preset_video" {
  for_each    = { for preset in local.video_presets : preset.name => preset }
  container   = each.value.container
  description = each.value.description
  name        = each.key

  audio {
    audio_packing_mode = "SingleTrack"
    bit_rate           = each.value.audio_bit_rate
    channels           = 2
    codec              = "AAC"
    sample_rate        = 44100
  }

  audio_codec_options {
    profile = "AAC-LC"
  }

  video {
    bit_rate             = each.value.video_bit_rate
    codec                = "H.264"
    display_aspect_ratio = "auto"
    fixed_gop            = "true"
    frame_rate           = "auto"
    keyframes_max_dist   = 90
    max_height           = each.value.max_height
    max_width            = each.value.max_width
    padding_policy       = "NoPad"
    sizing_policy        = "ShrinkToFit"
  }

  video_codec_options = {
    Profile                  = "main"
    Level                    = "3.1"
    MaxReferenceFrames       = 3
    InterlacedMode           = "Progressive"
    ColorSpaceConversionMode = "Auto"
  }

  thumbnails {
    format         = "png"
    interval       = 300
    max_width      = "192"
    max_height     = "108"
    padding_policy = "NoPad"
    sizing_policy  = "ShrinkToFit"
  }
}
