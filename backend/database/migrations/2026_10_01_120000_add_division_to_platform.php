<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('division')->default('tutor')->after('role'); // tutor | law | platform
        });

        Schema::table('subjects', function (Blueprint $table) {
            $table->string('division')->default('tutor')->after('slug');
        });

        Schema::table('packages', function (Blueprint $table) {
            $table->string('division')->default('tutor')->after('name');
        });
    }

    public function down(): void
    {
        Schema::table('packages', function (Blueprint $table) {
            $table->dropColumn('division');
        });

        Schema::table('subjects', function (Blueprint $table) {
            $table->dropColumn('division');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('division');
        });
    }
};
