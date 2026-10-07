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
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.RootUser, cfg.RootPassword, ""),
		Secure: cfg.UseSSL,
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

// UploadPublic uploads an object to the public bucket
func (s *Storage) UploadPublic(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (minio.UploadInfo, error) {
	return s.client.PutObject(ctx, s.bucketPublic, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
}

// UploadPrivate uploads an object to the original private bucket
func (s *Storage) UploadPrivate(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (minio.UploadInfo, error) {
	return s.client.PutObject(ctx, s.bucketOriginal, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
}

// PresignedGet generates a presigned download URL for private objects
func (s *Storage) PresignedGet(ctx context.Context, bucket, objectName string, expiry time.Duration) (*url.URL, error) {
	return s.client.PresignedGetObject(ctx, bucket, objectName, expiry, nil)
}
