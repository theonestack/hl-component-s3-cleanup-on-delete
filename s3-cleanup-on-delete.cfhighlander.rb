CfhighlanderTemplate do
  Name 's3-cleanup-on-delete'
  Description "s3-cleanup-on-delete - #{component_version}"

  Parameters do
    ComponentParam 'Buckets'
  end


end
