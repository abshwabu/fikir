package storage

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/abshwabu/fikir/backend/internal/config"
)

// Storage wraps minio.Client
type Storage struct {
	client         *minio.Client
	bucketOriginal string
	bucketPublic   string
}

// New constructs a MinIO/S3 storage client
func New(cfg config.MinIOConfig) (*Storage, error) {
	region := cfg.Region
	if region == "" {
		region = "us-east-1"
	}
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.RootUser, cfg.RootPassword, ""),
		Secure: cfg.UseSSL,
		Region: region,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create minio client: %w", err)
	}

	return &Storage{
		client:         client,
		bucketOriginal: cfg.BucketOriginal,
		bucketPublic:   cfg.BucketPublic,
	}, nil
}

// Client returns the underlying MinIO client
func (s *Storage) Client() *minio.Client {
	return s.client
}

func (s *Storage) BucketOriginal() string {
	return s.bucketOriginal
}

func (s *Storage) BucketPublic() string {
	return s.bucketPublic
}

// UploadPublic uploads an object to the public bucket with immutable Cache-Control
func (s *Storage) UploadPublic(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (minio.UploadInfo, error) {
	opts := minio.PutObjectOptions{
		ContentType:  contentType,
		CacheControl: "public, max-age=31536000, immutable",
	}
	return s.client.PutObject(ctx, s.bucketPublic, objectName, reader, size, opts)
}

// UploadPrivate uploads an object to the original private bucket
func (s *Storage) UploadPrivate(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (minio.UploadInfo, error) {
	return s.client.PutObject(ctx, s.bucketOriginal, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
}

// PresignedPutOriginal generates a presigned PUT URL for client-direct upload to the private bucket
func (s *Storage) PresignedPutOriginal(ctx context.Context, objectName string, expiry time.Duration) (*url.URL, error) {
	return s.client.PresignedPutObject(ctx, s.bucketOriginal, objectName, expiry)
}

// PresignedPutPublic generates a presigned PUT URL for client-direct upload to the public bucket
func (s *Storage) PresignedPutPublic(ctx context.Context, objectName string, expiry time.Duration) (*url.URL, error) {
	return s.client.PresignedPutObject(ctx, s.bucketPublic, objectName, expiry)
}

// PresignedGet generates a presigned download URL for private objects
func (s *Storage) PresignedGet(ctx context.Context, bucket, objectName string, expiry time.Duration) (*url.URL, error) {
	return s.client.PresignedGetObject(ctx, bucket, objectName, expiry, nil)
}

// GetObjectOriginal downloads an object from the private originals bucket
func (s *Storage) GetObjectOriginal(ctx context.Context, objectName string) (*minio.Object, error) {
	return s.client.GetObject(ctx, s.bucketOriginal, objectName, minio.GetObjectOptions{})
}

// DeleteObject deletes an object from a specified bucket
func (s *Storage) DeleteObject(ctx context.Context, bucket, objectName string) error {
	return s.client.RemoveObject(ctx, bucket, objectName, minio.RemoveObjectOptions{})
}
