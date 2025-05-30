# typed: strong
# frozen_string_literal: true

require "excon"
require "json"
require "sorbet-runtime"

require "dependabot/errors"
require "dependabot/shared_helpers"
require "dependabot/update_checkers/version_filters"
require "dependabot/package/package_latest_version_finder"
require "dependabot/github_actions/update_checker"
require "dependabot/github_actions/package/package_details_fetcher"
require "dependabot/credential"
require "dependabot/version"

module Dependabot
  module GithubActions
    class UpdateChecker
      class LatestVersionFinder
        extend T::Sig

        sig do
          params(
            dependency: Dependabot::Dependency,
            credentials: T.nilable(T::Array[Dependabot::Credential])
          ).void
        end
        def initialize(dependency:, credentials:, dependency_files:)
          @dependency = dependency
          @credentials = credentials
        end

        sig { returns(Dependabot::Dependency) }
        attr_reader :dependency
        sig { returns(T::Array[Dependabot::Credential]) }
        attr_reader :credentials

        sig { returns(T.nilable(T.any(Dependabot::Version, String))) }
        def fetch_latest_version
          PackageDetailsFetcher.new(
            dependency: dependency,
            credentials: credentials
          ).fetch_details
        end
      end
    end
  end
end
