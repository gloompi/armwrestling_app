import { supabase } from "./supabaseClient";

/**
 * The default storage bucket used for media uploads. You can override
 * this value via the NEXT_PUBLIC_SUPABASE_STORAGE_BUCKET environment
 * variable. If not provided, "media" will be used.
 */
export const storageBucket = process.env.NEXT_PUBLIC_SUPABASE_STORAGE_BUCKET || "media";

/**
 * Uploads a file to Supabase Storage and returns a public URL. The file
 * will be uploaded under a randomly generated filename to avoid name
 * collisions. After upload, the file's public URL is generated using
 * `getPublicUrl` so that it can be stored directly in your database
 * (e.g. as the preview_url or video url). If any error occurs, the
 * error is thrown to the caller.
 *
 * @param file The File object to upload
 * @param bucket Optional bucket name; defaults to `storageBucket`
 * @returns A promise resolving to the public URL of the uploaded file
 */
export async function uploadFile(
  file: File,
  bucket: string = storageBucket,
): Promise<string> {
  const ext = file.name.split(".").pop();
  // Generate a unique filename using a timestamp and random string
  const fileName = `${Date.now()}-${Math.random().toString(36).substring(2)}.${ext}`;
  const { data: uploadData, error: uploadError } = await supabase.storage
    .from(bucket)
    .upload(fileName, file, { upsert: true });
  if (uploadError) {
    throw uploadError;
  }
  const path = uploadData?.path ?? fileName;
  const { data: publicData } = supabase.storage.from(bucket).getPublicUrl(path);
  return publicData.publicUrl;
}