# -*- coding: UTF-8 -*-
require 'fastlane/action'
require_relative '../helper/alioss_helper'
require 'aliyun/oss'
require 'json'

module Fastlane
  module Actions
    class AliossAction < Action
      def self.run(params)
        UI.message("The alioss plugin is working!")

        endpoint = params[:endpoint]
        bucket_name = params[:bucket_name]
        access_key_id = params[:access_key_id]
        access_key_secret = params[:access_key_secret]
        path_for_app_name = params[:app_name]
        html_header_title = params[:html_header_title]

        build_file = [
            params[:ipa],
            params[:apk]
        ].detect { |e| !e.to_s.empty? }

        if build_file.nil?
          UI.user_error!("请提供构建文件")
        end

        UI.message "endpoint: #{endpoint}  bucket_name: #{bucket_name} app_path: #{path_for_app_name}"
        UI.message "构建文件: #{build_file}"


        download_domain = params[:download_domain]
        if download_domain.nil?
          download_domain = "https://#{bucket_name}.#{endpoint}/"
        end

        update_description = params[:update_description]
        if update_description.nil?
          update_description = ""
        end

        # create aliyun oss client
        client = Aliyun::OSS::Client.new(
            endpoint: endpoint,
            access_key_id: access_key_id,
            access_key_secret: access_key_secret
        )

        bucket = client.get_bucket(bucket_name)
        file_size = File.size(build_file)
        filename = File.basename(build_file)
        timestamp = Time.now
        file_name_with_timestamp = "#{timestamp.strftime('%Y%m%d%H%M%S')}_" + filename
        bucket_path = "#{path_for_app_name}/"

        UI.message "正在上传文件，可能需要几分钟，请稍等..."
        bucket.put_object(bucket_path + file_name_with_timestamp, :file => build_file)
        download_url = "#{download_domain}#{bucket_path}#{file_name_with_timestamp}"
        UI.message "download_url: #{download_url}"
        download_url
      end

      def self.description
        "aliyun oss upload"
      end

      def self.authors
        ["woodwu"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :endpoint,
                                       env_name: "ALIOSS_ENDPOINT",
                                       description: "请提供 endpoint，Endpoint 表示 OSS 对外服务的访问域名。OSS 以 HTTP RESTful API 的形式对外提供服务，当访问不同的 Region 的时候，需要不同的域名。",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :access_key_id,
                                       env_name: "ALIOSS_ACCESS_KEY_ID",
                                       description: "请提供 AccessKeyId，OSS 通过使用 AccessKeyId 和 AccessKeySecret 对称加密的方法来验证某个请求的发送者身份。AccessKeyId 用于标识用户。",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :access_key_secret,
                                       env_name: "ALIOSS_ACCESS_KEY_SECRET",
                                       description: "请提供 AccessKeySecret，OSS 通过使用 AccessKeyId 和 AccessKeySecret 对称加密的方法来验证某个请求的发送者身份。AccessKeySecret 是用户用于加密签名字符串和 OSS 用来验证签名字符串的密钥，必须保密。",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :bucket_name,
                                       env_name: "ALIOSS_BUCKET_NAME",
                                       description: "请提供 bucket_name，存储空间（Bucket）是您用于存储对象（Object）的容器，所有的对象都必须隶属于某个存储空间。存储空间具有各种配置属性，包括地域、访问权限、存储类型等。您可以根据实际需求，创建不同类型的存储空间来存储不同的数据。",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :apk,
                                       env_name: "ALIOSS_APK",
                                       description: "APK文件路径",
                                       default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH],
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("请检查apk文件路径 '#{value}' )") unless File.exist?(value)
                                       end,
                                       conflicting_options: [:ipa],
                                       conflict_block: proc do |value|
                                         UI.user_error!("在运行的选项中不能使用 'apk' and '#{value.key}')")
                                       end),
          FastlaneCore::ConfigItem.new(key: :ipa,
                                       env_name: "ALIOSS_IPA",
                                       description: "IPA文件路径，可选的action有_gym_和_xcodebuild_，Mac是.app文件，安卓是.apk文件。",
                                       default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("请检查apk文件路径 '#{value}' ") unless File.exist?(value)
                                       end,
                                       conflicting_options: [:apk],
                                       conflict_block: proc do |value|
                                         UI.user_error!("在运行的选项中不能使用 'ipa' 和 '#{value.key}'")
                                       end),
          FastlaneCore::ConfigItem.new(key: :app_name,
                                       env_name: "APP_NAME",
                                       description: "App的名称，你的服务器中可能有多个App，需要用App名称来区分，这个名称也是文件目录的名称，可以是App的路径。",
                                       default_value: "app",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :download_domain,
                                       env_name: "ALIOSS_DOWNLOAD_DOMAIN",
                                       description: "下载域名，默认是https://{bucket_name}.{endpoint}/",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :html_header_title,
                                       env_name: "ALIOSS_HTML_HEADER_TITLE",
                                       description: "html下载页面header title",
                                       default_value: "很高兴邀请您安装我们的App，测试并反馈问题，便于我们及时解决您遇到的问题，十分谢谢！Thanks♪(･ω･)ﾉ",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :update_description,
                                       env_name: "ALIOSS_UPDATE_DESCRIPTION",
                                       description: "设置app更新日志，描述你修改了哪些内容。",
                                       optional: true,
                                       type: String)
      ]
      end

      def self.is_supported?(platform)
        true
      end

    end
  end
end
