# frozen_string_literal: true

# A journal on the review page: everything a reviewer weighs its hours against. `params[:writing]` is the AI share
# Pangram gave each journal id and `params[:earlier]` the JournalReview an earlier submission made of it.
class ReviewJournalSerializer < JournalSerializer
  typelize tracked_minutes: [ :number, nullable: true ], hours_self_claimed: [ :boolean, nullable: true ],
           fraction_ai: [ :number, nullable: true ],
           timelapses: "Array<{ id: string; name: string | null; duration_minutes: number; playback_url: string | null; thumbnail_url: string | null; url: string }>",
           earlier: "{ approved_minutes: number; reason: string | null; note: string | null } | null"
  attributes :tracked_minutes, :hours_self_claimed
  attribute(:fraction_ai) { |journal| params[:writing]&.[](journal.id)&.to_f }
  attribute(:timelapses) do |journal|
    journal.lapse_timelapses.map do |t|
      { id: t.public_id, name: t.name, duration_minutes: t.duration_minutes, playback_url: t.playback_url, thumbnail_url: t.thumbnail_url, url: t.url }
    end
  end
  attribute(:earlier) do |journal|
    review = params[:earlier]&.[](journal.id)
    review && { approved_minutes: review.approved_minutes, reason: review.reason, note: review.note }
  end
end
