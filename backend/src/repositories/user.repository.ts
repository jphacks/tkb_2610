import { supabase } from "../lib/supabase.js";

export type UserProfile = {
  id: string;
  displayName: string;
  createdAt: string;
};

export async function findUserProfileById(
  userId: string,
): Promise<UserProfile | null> {
  const { data, error } = await supabase
    .from("users")
    .select("id, display_name, created_at")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`User profile lookup failed: ${error.message}`);
  }

  if (!data) {
    return null;
  }

  return {
    id: data.id,
    displayName: data.display_name,
    createdAt: data.created_at,
  };
}

export type UpdatedUserName = {
  id: string;
  displayName: string;
};

export async function updateUserDisplayName(
  userId: string,
  displayName: string,
): Promise<UpdatedUserName | null> {
  const { data, error } = await supabase
    .from("users")
    .update({ display_name: displayName })
    .eq("id", userId)
    .select("id, display_name")
    .maybeSingle();

  if (error) {
    throw new Error(`User display name update failed: ${error.message}`);
  }

  if (!data) {
    return null;
  }

  return {
    id: data.id,
    displayName: data.display_name,
  };
}
