# typed: strong
# frozen_string_literal: true

require "json"
require "time"
require "cgi"
require "excon"
require "nokogiri"
require "sorbet-runtime"
require "dependabot/registry_client"
require "dependabot/github_actions"
require "dependabot/package/package_release"
require "dependabot/package/package_details"

module Dependabot
  module GithubActions
    module Package
      class PackageDetailsFetcher
        def initialize(dependency:, dependency_files:, credentials:)
          @dependency = dependency
          @dependency_files = dependency_files
          @credentials = credentials
        end

        def fetch_details
          return current_commit unless git_commit_checker.pinned?

          # If the dependency is pinned to a tag that looks like a version then
          # we want to update that tag.
          if git_commit_checker.pinned_ref_looks_like_version? && latest_version_tag
            latest_version = latest_version_tag&.fetch(:version)
            return current_version if shortened_semver_eq?(dependency.version, latest_version.to_s)

            return latest_version
          end

          if git_commit_checker.pinned_ref_looks_like_commit_sha? && latest_version_tag
            latest_version = latest_version_tag&.fetch(:version)
            return latest_commit_for_pinned_ref unless git_commit_checker.local_tag_for_pinned_sha

            return latest_version
          end

          # If the dependency is pinned to a tag that doesn't look like a
          # version or a commit SHA then there's nothing we can do.
          nil
        end

        private

        sig { returns(T.nilable(String)) }
        def current_commit
          git_commit_checker.head_commit_for_current_branch
        end

        sig { returns(T::Boolean) }
        def git_dependency?
          git_commit_checker.git_dependency?
        end

        sig { returns(Dependabot::GitCommitChecker) }
        def git_commit_checker
          @git_commit_checker ||= T.let(
            git_commit_checker_for(nil),
            T.nilable(Dependabot::GitCommitChecker)
          )
        end

        sig { params(source: T.nilable(T::Hash[Symbol, String])).returns(Dependabot::GitCommitChecker) }
        def git_commit_checker_for(source)
          @git_commit_checkers ||= T.let(
            {},
            T.nilable(T::Hash[T.nilable(T::Hash[Symbol, String]), Dependabot::GitCommitChecker])
          )

          @git_commit_checkers[source] ||= Dependabot::GitCommitChecker.new(
            dependency: dependency,
            credentials: credentials,
            ignored_versions: ignored_versions,
            raise_on_ignored: raise_on_ignored,
            consider_version_branches_pinned: true,
            dependency_source_details: source
          )
        end

        sig { params(base: T.nilable(String), other: String).returns(T::Boolean) }
        def shortened_semver_eq?(base, other)
          return false unless base

          base_split = base.split(".")
          other_split = other.split(".")
          return false unless base_split.length <= other_split.length

          other_split[0..base_split.length - 1] == base_split
        end

        sig { params(sha: String).returns(T.nilable(String)) }
        def find_container_branch(sha)
          branches_including_ref = SharedHelpers.run_shell_command(
            "git branch --remotes --contains #{sha}",
            fingerprint: "git branch --remotes --contains <sha>"
          ).split("\n").map { |branch| branch.strip.gsub("origin/", "") }
          return if branches_including_ref.empty?

          current_branch = branches_including_ref.find { |branch| branch.start_with?("HEAD -> ") }

          if current_branch
            current_branch.delete_prefix("HEAD -> ")
          elsif branches_including_ref.size > 1
            raise "Multiple ambiguous branches (#{branches_including_ref.join(', ')}) include #{sha}!"
          else
            branches_including_ref.first
          end
        end
      end
    end
  end
end
