require "aws-sdk-s3"
require "stringio"

module R2
  class Storage
    DEFAULT_EXPIRY = 15.minutes

    def initialize(client: default_client, bucket: ENV.fetch("R2_BUCKET"))
      @client = client
      @bucket = bucket
    end

    def presigned_upload_url(key:, expires_in: DEFAULT_EXPIRY, content_type: nil)
      opts = { bucket: bucket, key: key, expires_in: expires_in.to_i }
      opts[:content_type] = content_type if content_type.present?

      presigner.presigned_url(:put_object, opts)
    end

    def presigned_download_url(key:, expires_in: DEFAULT_EXPIRY)
      presigner.presigned_url(:get_object, bucket: bucket, key: key, expires_in: expires_in.to_i)
    end

    def upload_io(key, io, content_type: nil)
      data = extract_data(io)
      client.put_object(
        bucket: bucket,
        key: key,
        body: data,
        content_type: content_type
      )
    end

    def download(key)
      response = client.get_object(bucket: bucket, key: key)
      StringIO.new(response.body.read)
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def object_exists?(key)
      client.head_object(bucket: bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end

    private

    attr_reader :client, :bucket

    def presigner
      @presigner ||= Aws::S3::Presigner.new(client: client)
    end

    def default_client
      Aws::S3::Client.new(
        region: ENV.fetch("R2_REGION", "auto"),
        endpoint: ENV.fetch("R2_ENDPOINT") { default_endpoint },
        credentials: Aws::Credentials.new(
          ENV.fetch("R2_ACCESS_KEY_ID"),
          ENV.fetch("R2_SECRET_ACCESS_KEY")
        ),
        force_path_style: false
      )
    end

    def default_endpoint
      account_id = ENV.fetch("R2_ACCOUNT_ID")
      "https://#{account_id}.r2.cloudflarestorage.com"
    end

    def extract_data(io)
      return io if io.is_a?(String)
      return io.read if io.respond_to?(:read)

      io.to_s
    end
  end
end
